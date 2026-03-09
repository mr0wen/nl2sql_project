class Diretor < ApplicationRecord
  self.table_name = 'diretores'
  has_many :filmes
end