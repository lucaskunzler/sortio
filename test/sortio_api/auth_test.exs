defmodule SortioApi.AuthTest do
  use ExUnit.Case, async: true
  use SortioApi.ConnCase

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Sortio.Repo)

    # Create a test user with known credentials
    user = insert(:user, email: "test@example.com")

    %{user: user}
  end

  describe "POST /login" do
    test "valid credentials return 200 with token and user data", %{user: user} do
      params = %{
        "email" => "test@example.com",
        "password" => "password123"
      }

      conn = make_request("/login", :post, Jason.encode!(params))

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)

      assert body["token"]
      assert is_binary(body["token"])
      assert body["user"]["id"] == user.id
      assert body["user"]["email"] == "test@example.com"
      assert body["user"]["name"] == "Test User"
      refute Map.has_key?(body["user"], "password")
      refute Map.has_key?(body["user"], "password_hash")
    end

    test "invalid email returns 401" do
      params = %{
        "email" => "wrong@example.com",
        "password" => "password123"
      }

      conn = make_request("/login", :post, Jason.encode!(params))

      assert conn.status == 401

      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Invalid email or password"
    end

    test "invalid password returns 401" do
      params = %{
        "email" => "test@example.com",
        "password" => "wrongpassword"
      }

      conn = make_request("/login", :post, Jason.encode!(params))

      assert conn.status == 401

      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Invalid email or password"
    end

    test "missing email returns 400" do
      params = %{
        "password" => "password123"
      }

      conn = make_request("/login", :post, Jason.encode!(params))

      assert conn.status == 400

      body = Jason.decode!(conn.resp_body)
      assert body["error"]
      assert String.contains?(String.downcase(body["error"]), "email")
    end

    test "missing password returns 400" do
      params = %{
        "email" => "test@example.com"
      }

      conn = make_request("/login", :post, Jason.encode!(params))

      assert conn.status == 400

      body = Jason.decode!(conn.resp_body)
      assert body["error"]
      assert String.contains?(String.downcase(body["error"]), "password")
    end

    test "malformed JSON raises ParseError" do
      # Invalid JSON - missing closing brace
      # Note: Plug.Parsers will raise an exception for malformed JSON
      assert_raise Plug.Parsers.ParseError, fn ->
        SortioApi.Router.init([])
        |> then(fn opts ->
          Plug.Test.conn(:post, "/login", "{\"email\": \"test@example.com\"")
          |> Plug.Conn.put_req_header("content-type", "application/json")
          |> SortioApi.Router.call(opts)
        end)
      end
    end
  end

  describe "GET /me" do
    test "with valid token returns 200 with user data", %{user: user} do
      # First login to get token
      login_params = %{
        "email" => "test@example.com",
        "password" => "password123"
      }

      login_conn = make_request("/login", :post, Jason.encode!(login_params))
      login_body = Jason.decode!(login_conn.resp_body)
      token = login_body["token"]

      # Then access protected route
      conn = make_authenticated_request("/me", :get, token)

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      assert body["user"]["id"] == user.id
      assert body["user"]["email"] == "test@example.com"
      assert body["user"]["name"] == "Test User"
    end

    test "without token returns 401" do
      conn = make_request("/me", :get, nil)

      assert conn.status == 401

      body = Jason.decode!(conn.resp_body)
      assert body["error"]
      assert String.contains?(String.downcase(body["error"]), "authorization")
    end

    test "with invalid token returns 401" do
      conn = make_authenticated_request("/me", :get, "invalid.token.here")

      assert conn.status == 401

      body = Jason.decode!(conn.resp_body)
      assert body["error"] =~ "Invalid or expired token"
    end

    test "with malformed authorization header returns 401" do
      opts = SortioApi.Router.init([])

      conn =
        Plug.Test.conn(:get, "/me")
        |> Plug.Conn.put_req_header("authorization", "NotBearer token")
        |> SortioApi.Router.call(opts)

      assert conn.status == 401

      body = Jason.decode!(conn.resp_body)
      assert body["error"]
      assert String.contains?(String.downcase(body["error"]), "authorization")
    end
  end
end
