class Ator < ApplicationRecord
  self.table_name = 'atores'
  has_and_belongs_to_many :filmes, join_table: :filmes_atores
end