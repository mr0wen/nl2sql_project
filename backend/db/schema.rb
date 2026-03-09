# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_09_194533) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "atores", force: :cascade do |t|
    t.string "nome", null: false
  end

  create_table "classificacao_indicativa", force: :cascade do |t|
    t.string "descricao", null: false
  end

  create_table "diretores", force: :cascade do |t|
    t.string "nome", null: false
  end

  create_table "filmes", force: :cascade do |t|
    t.integer "ano_lancamento"
    t.decimal "avaliacao_imdb", precision: 3, scale: 1
    t.bigint "classificacao_indicativa_id"
    t.bigint "diretor_id"
    t.integer "duracao_minutos"
    t.integer "pontuacao_meta"
    t.text "poster_link"
    t.decimal "receita", precision: 15, scale: 2
    t.text "sinopse"
    t.string "titulo", null: false
    t.integer "votos"
    t.index ["classificacao_indicativa_id"], name: "index_filmes_on_classificacao_indicativa_id"
    t.index ["diretor_id"], name: "index_filmes_on_diretor_id"
  end

  create_table "filmes_atores", id: false, force: :cascade do |t|
    t.bigint "ator_id", null: false
    t.bigint "filme_id", null: false
    t.integer "ordem_credito"
    t.index ["ator_id"], name: "index_filmes_atores_on_ator_id"
    t.index ["filme_id"], name: "index_filmes_atores_on_filme_id"
  end

  create_table "filmes_generos", id: false, force: :cascade do |t|
    t.bigint "filme_id", null: false
    t.bigint "genero_id", null: false
    t.index ["filme_id"], name: "index_filmes_generos_on_filme_id"
    t.index ["genero_id"], name: "index_filmes_generos_on_genero_id"
  end

  create_table "generos", force: :cascade do |t|
    t.string "nome", null: false
  end

  create_table "movies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "distributor"
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "worldwide_gross"
    t.integer "year"
  end

  add_foreign_key "filmes", "classificacao_indicativa"
  add_foreign_key "filmes", "diretores", column: "diretor_id"
  add_foreign_key "filmes_atores", "atores", column: "ator_id"
  add_foreign_key "filmes_atores", "filmes"
  add_foreign_key "filmes_generos", "filmes"
  add_foreign_key "filmes_generos", "generos"
end
