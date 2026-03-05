# backend/db/seeds.rb
require 'open-uri'
require 'nokogiri'

puts "Limpando a base de dados..."
Movie.destroy_all

url = "https://en.wikipedia.org/wiki/List_of_highest-grossing_superhero_films"
puts "Iniciando o web scraping de #{url}..."

begin
  html = URI.open(url)
  doc = Nokogiri::HTML(html)
  
  table = doc.at_css('table.wikitable')
  
  # 1. O Golpe Fatal na Sujeira: 
  # Remove TODAS as tags <sup> (que abrigam o [3], [4], etc) do HTML da tabela 
  # antes de tentarmos extrair qualquer texto.
  table.search('sup').remove

  # 2. A Abordagem Matricial:
  # Renderizar a tabela em uma matriz 2D para resolver rowspans nativamente.
  rows = table.css('tr')
  matrix = Array.new(rows.length) { [] }

  rows.each_with_index do |row, row_idx|
    col_idx = 0
    row.css('th, td').each do |cell|
      # Avança a coluna se a posição atual já foi preenchida por um rowspan de uma linha acima
      while matrix[row_idx][col_idx] != nil
        col_idx += 1
      end

      rowspan = (cell['rowspan'] || 1).to_i
      colspan = (cell['colspan'] || 1).to_i
      text = cell.text.strip

      # Projeta o valor na matriz, preenchendo todos os "quadrados" do rowspan/colspan
      rowspan.times do |r_offset|
        colspan.times do |c_offset|
          if matrix[row_idx + r_offset]
            matrix[row_idx + r_offset][col_idx + c_offset] = text
          end
        end
      end
      
      col_idx += colspan
    end
  end

  # 3. Inserção Limpa no Banco de Dados
  filmes_salvos = 0
  
  matrix[1..-1].each do |row_data|
    next if row_data.nil? || row_data.compact.length < 6 
    
    title = row_data[1]
    gross_raw = row_data[2]
    year_raw = row_data[3]
    # A coluna row_data[4] (Universo) será sumariamente ignorada
    distributor = row_data[5]

    worldwide_gross = gross_raw.gsub(/[^\d]/, '').to_i
    year = year_raw[0..3].to_i 

    Movie.create!(
      title: title,
      worldwide_gross: worldwide_gross,
      year: year,
      distributor: distributor
    )
    filmes_salvos += 1
  end

  puts "Scraping concluído! #{filmes_salvos} filmes inseridos. Coluna 'universe' ignorada com sucesso."
rescue => e
  puts "Ocorreu um erro durante o scraping: #{e.message}"
end