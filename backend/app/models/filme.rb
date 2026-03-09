class Filme < ApplicationRecord
  self.table_name = 'filmes'
  belongs_to :diretor, optional: true
  belongs_to :classificacao_indicativa, optional: true

  has_and_belongs_to_many :atores, join_table: :filmes_atores
  has_and_belongs_to_many :generos, join_table: :filmes_generos
end