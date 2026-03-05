class RemoveUniverseFromMovies < ActiveRecord::Migration[8.1]
  def change
    remove_column :movies, :universe, :string
  end
end
