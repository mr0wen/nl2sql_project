class Genero < ApplicationRecord
  self.table_name = 'generos'
  has_and_belongs_to_many :filmes, join_table: :filmes_generos
end