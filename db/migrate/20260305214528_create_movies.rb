class CreateMovies < ActiveRecord::Migration[8.1]
  def change
    create_table :movies do |t|
      t.string :title
      t.string :universe
      t.string :distributor
      t.bigint :worldwide_gross
      t.integer :year

      t.timestamps
    end
  end
end
