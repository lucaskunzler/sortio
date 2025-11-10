defmodule SortioApi.RegistrationTest do
  use ExUnit.Case, async: true
  use SortioApi.ConnCase

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Sortio.Repo)
  end

  describe "POST /register/" do
    test "valid registration returns 201 with user data and token" do
      params = %{
        "name" => "Test User",
        "email" => "test@example.com",
        "password" => "password123"
      }

      conn = make_request("/register", :post, Jason.encode!(params))

      assert conn.status == 201

      body = Jason.decode!(conn.resp_body)

      assert body["token"]
      assert is_binary(body["token"])
      assert body["user"]["name"] == "Test User"
      assert body["user"]["email"] == "test@example.com"
      assert Map.has_key?(body["user"], "id")
      refute Map.has_key?(body["user"], "password")
      refute Map.has_key?(body["user"], "password_hash")
    end

    test "duplicate email returns 422 with error" do
      params = %{
        "name" => "First User",
        "email" => "duplicate@example.com",
        "password" => "password123"
      }

      # Create first user
      conn = make_request("/register", :post, Jason.encode!(params))
      assert conn.status == 201

      # Attempt to create user with same email
      params2 = %{
        "name" => "Second User",
        "email" => "duplicate@example.com",
        "password" => "password456"
      }

      conn = make_request("/register", :post, Jason.encode!(params2))

      assert conn.status == 422

      body = Jason.decode!(conn.resp_body)
      assert body["error"]
      assert String.contains?(String.downcase(body["error"]), "email")
    end

    test "invalid email format returns 422" do
      params = %{
        "name" => "Test User",
        "email" => "invalid-email",
        "password" => "password123"
      }

      conn = make_request("/register", :post, Jason.encode!(params))

      assert conn.status == 422

      body = Jason.decode!(conn.resp_body)
      assert body["error"]
      assert String.contains?(String.downcase(body["error"]), "email")
    end

    test "short password returns 422" do
      params = %{
        "name" => "Test User",
        "email" => "test@example.com",
        "password" => "123"
      }

      conn = make_request("/register", :post, Jason.encode!(params))

      assert conn.status == 422

      body = Jason.decode!(conn.resp_body)
      assert body["error"]
      assert String.contains?(String.downcase(body["error"]), "password")
    end

    test "missing fields return 422" do
      # Missing email
      params1 = %{
        "name" => "Test User",
        "password" => "password123"
      }

      conn = make_request("/register", :post, Jason.encode!(params1))
      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert body["error"]
      assert String.contains?(String.downcase(body["error"]), "missing required fields")

      # Missing password
      params2 = %{
        "name" => "Test User",
        "email" => "test@example.com"
      }

      conn = make_request("/register", :post, Jason.encode!(params2))
      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert body["error"]
      assert String.contains?(String.downcase(body["error"]), "missing required fields")

      # Missing name
      params3 = %{
        "email" => "test@example.com",
        "password" => "password123"
      }

      conn = make_request("/register", :post, Jason.encode!(params3))
      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert body["error"]
      assert String.contains?(String.downcase(body["error"]), "missing required fields")
    end

    test "malformed JSON raises ParseError" do
      # Invalid JSON - missing closing brace
      # Note: Plug.Parsers will raise an exception for malformed JSON
      assert_raise Plug.Parsers.ParseError, fn ->
        SortioApi.Router.init([])
        |> then(fn opts ->
          Plug.Test.conn(:post, "/register", "{\"name\": \"Test\"")
          |> Plug.Conn.put_req_header("content-type", "application/json")
          |> SortioApi.Router.call(opts)
        end)
      end
    end

    test "empty JSON object returns 422" do
      conn = make_request("/register", :post, Jason.encode!(%{}))

      assert conn.status == 422

      body = Jason.decode!(conn.resp_body)
      assert body["error"]
    end

    test "extremely long name returns 422" do
      # Generate a name longer than typical database limits (e.g., 255 chars)
      long_name = String.duplicate("a", 300)

      params = %{
        "name" => long_name,
        "email" => "test@example.com",
        "password" => "password123"
      }

      conn = make_request("/register", :post, Jason.encode!(params))

      assert conn.status == 422

      body = Jason.decode!(conn.resp_body)
      assert body["error"]
      assert String.contains?(String.downcase(body["error"]), "name")
    end

    test "extremely long email returns 422" do
      # Generate an email longer than typical limits
      long_email = String.duplicate("a", 300) <> "@example.com"

      params = %{
        "name" => "Test User",
        "email" => long_email,
        "password" => "password123"
      }

      conn = make_request("/register", :post, Jason.encode!(params))

      assert conn.status == 422

      body = Jason.decode!(conn.resp_body)
      assert body["error"]
      assert String.contains?(String.downcase(body["error"]), "email")
    end

    test "returned token can be used to access protected endpoints" do
      params = %{
        "name" => "New User",
        "email" => "newuser@example.com",
        "password" => "password123"
      }

      # Register and get token
      register_conn = make_request("/register", :post, Jason.encode!(params))
      assert register_conn.status == 201

      register_body = Jason.decode!(register_conn.resp_body)
      token = register_body["token"]

      # Use token to access /me endpoint
      me_conn = make_authenticated_request("/me", :get, token)
      assert me_conn.status == 200

      me_body = Jason.decode!(me_conn.resp_body)
      assert me_body["user"]["email"] == "newuser@example.com"
      assert me_body["user"]["name"] == "New User"
    end
  end
end
