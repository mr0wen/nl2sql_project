namespace :imdb do
  desc "Importa os dados relacionais do IMDB a partir dos arquivos SQL"
  task import_relational: :environment do
    # Diretório onde os arquivos SQL foram colocados
    sql_dir = Rails.root.join('db', 'imdb top 1000') 
    
    files = [
      '1_insert_atores.sql',
      '2_insert_classificacao_indicativa.sql',
      '3_insert_diretores.sql',
      '4_insert_generos.sql',
      '5_insert_filmes.sql',
      '6_insert_filmes_atores.sql',
      '7_insert_filmes_generos.sql'
    ]

    ActiveRecord::Base.transaction do
      files.each do |file_name|
        path = sql_dir.join(file_name)
        if File.exist?(path)
          puts "Executando #{file_name}..."
          sql = File.read(path)
          ActiveRecord::Base.connection.execute(sql)
        else
          puts "Aviso: Arquivo #{file_name} não encontrado."
        end
      end
    end

    # Sincronizar as sequências do PostgreSQL
    # Essencial porque os INSERTs manuais "pularam" o auto-incremento
    tables = %w[atores classificacao_indicativa diretores generos filmes]
    tables.each do |table|
      ActiveRecord::Base.connection.execute(
        "SELECT setval('#{table}_id_seq', COALESCE((SELECT MAX(id)+1 FROM #{table}), 1), false)"
      )
    end

    puts "Importação concluída com sucesso!"
  end
end