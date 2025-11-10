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

  def participant_factory do
    %Participant{
      user: build(:user),
      raffle: build(:raffle)
    }
  end

  def raffle_factory do
    %Raffle{
      title: sequence(:title, &"Test Raffle #{&1}"),
      description: "Test description",
      status: "open",
      draw_date: DateTime.add(DateTime.utc_now(), 60, :second),
      creator: build(:user)
    }
  end

  def drawn_raffle_factory do
    winner = build(:user)

    %Raffle{
      title: sequence(:title, &"Drawn Raffle #{&1}"),
      description: "This raffle has been drawn",
      status: "drawn",
      draw_date: DateTime.add(DateTime.utc_now(), -3600, :second),
      drawn_at: DateTime.utc_now(),
      winner: winner,
      creator: build(:user)
    }
  end
end
