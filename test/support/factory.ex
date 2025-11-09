defmodule Sortio.Factory do
  @moduledoc """
  ExMachina factory for generating test data.
  """
  use ExMachina.Ecto, repo: Sortio.Repo

  alias Sortio.Accounts.User
  alias Sortio.Raffles.Raffle
  alias Sortio.Raffles.Participant

  def user_factory do
    %User{
      name: "Test User",
      email: sequence(:email, &"user#{&1}@example.com"),
      password_hash: Bcrypt.hash_pwd_salt("password123")
    }
  end

  def raffle_factory do
    %Raffle{
      title: sequence(:title, &"Test Raffle #{&1}"),
      description: "Test description",
      status: "open",
      creator: build(:user)
    }
  end

  def participant_factory do
    %Participant{
      user: build(:user),
      raffle: build(:raffle)
    }
  end
end
