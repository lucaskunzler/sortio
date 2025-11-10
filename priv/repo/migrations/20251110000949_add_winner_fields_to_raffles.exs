defmodule Sortio.Repo.Migrations.AddWinnerFieldsToRaffles do
  use Ecto.Migration

  def change do
    alter table(:raffles) do
      add(:winner_id, references(:users, type: :binary_id, on_delete: :nilify_all))
      add(:drawn_at, :utc_datetime_usec)
    end

    create(index(:raffles, [:winner_id]))
  end
end
