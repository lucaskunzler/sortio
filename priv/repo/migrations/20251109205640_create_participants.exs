defmodule Sortio.Repo.Migrations.CreateParticipants do
  use Ecto.Migration

  def change do
    create table(:participants) do
      add(:user_id, references(:users, on_delete: :restrict))
      add(:raffle_id, references(:raffles, on_delete: :delete_all))

      timestamps()
    end

    create(index(:participants, [:user_id]))
    create(unique_index(:participants, [:user_id, :raffle_id]))
  end
end
