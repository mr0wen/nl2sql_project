class CreateImdbRelationalTables < ActiveRecord::Migration[8.1]
  def change
    create_table :classificacao_indicativa do |t|
      t.string :descricao, null: false
    end

    create_table :diretores do |t|
      t.string :nome, null: false
    end

    create_table :atores do |t|
      t.string :nome, null: false
    end

    create_table :generos do |t|
      t.string :nome, null: false
    end

    create_table :filmes do |t|
      t.string :titulo, null: false
      t.integer :ano_lancamento
      t.integer :duracao_minutos
      t.text :sinopse
      t.decimal :avaliacao_imdb, precision: 3, scale: 1
      t.integer :pontuacao_meta
      t.integer :votos
      t.decimal :receita, precision: 15, scale: 2
      t.text :poster_link
      
      t.references :diretor, foreign_key: { to_table: :diretores }
      t.references :classificacao_indicativa, foreign_key: { to_table: :classificacao_indicativa }
    end

    # Tabelas de junção (Muitos-para-Muitos) sem chave primária própria
    create_table :filmes_atores, id: false do |t|
      t.references :filme, null: false, foreign_key: { to_table: :filmes }
      t.references :ator, null: false, foreign_key: { to_table: :atores }
      t.integer :ordem_credito
    end

    create_table :filmes_generos, id: false do |t|
      t.references :filme, null: false, foreign_key: { to_table: :filmes }
      t.references :genero, null: false, foreign_key: { to_table: :generos }
    end
  end
end