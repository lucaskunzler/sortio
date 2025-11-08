defmodule SortioApi.RegistrationTest do
  use ExUnit.Case, async: false

  import SortioApi.ConnCase

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Sortio.Repo)
  end

  describe "POST /users/" do
    test "valid registration returns 201 with user data" do
      params = %{
        "name" => "Test User",
        "email" => "test@example.com",
        "password" => "password123"
      }

      conn = make_request("/users", :post, Jason.encode!(params))

      assert conn.status == 201

      body = Jason.decode!(conn.resp_body)

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
      conn = make_request("/users", :post, Jason.encode!(params))
      assert conn.status == 201

      # Attempt to create user with same email
      params2 = %{
        "name" => "Second User",
        "email" => "duplicate@example.com",
        "password" => "password456"
      }

      conn = make_request("/users", :post, Jason.encode!(params2))

      assert conn.status == 422

      body = Jason.decode!(conn.resp_body)
      assert body["error"] =~ "email"
    end

    test "invalid email format returns 422" do
      params = %{
        "name" => "Test User",
        "email" => "invalid-email",
        "password" => "password123"
      }

      conn = make_request("/users", :post, Jason.encode!(params))

      assert conn.status == 422

      body = Jason.decode!(conn.resp_body)
      assert body["error"] =~ "email"
    end

    test "short password returns 422" do
      params = %{
        "name" => "Test User",
        "email" => "test@example.com",
        "password" => "123"
      }

      conn = make_request("/users", :post, Jason.encode!(params))

      assert conn.status == 422

      body = Jason.decode!(conn.resp_body)
      assert body["error"] =~ "password"
    end

    test "missing fields return 422" do
      # Missing email
      params1 = %{
        "name" => "Test User",
        "password" => "password123"
      }

      conn = make_request("/users", :post, Jason.encode!(params1))
      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert body["error"] =~ "email"

      # Missing password
      params2 = %{
        "name" => "Test User",
        "email" => "test@example.com"
      }

      conn = make_request("/users", :post, Jason.encode!(params2))
      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert body["error"] =~ "password"

      # Missing name
      params3 = %{
        "email" => "test@example.com",
        "password" => "password123"
      }

      conn = make_request("/users", :post, Jason.encode!(params3))
      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert body["error"] =~ "name"
    end
  end
end
