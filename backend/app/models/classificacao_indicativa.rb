class ClassificacaoIndicativa < ApplicationRecord
  self.table_name = 'classificacao_indicativa'
  has_many :filmes
end