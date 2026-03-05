require 'open-uri'
require 'nokogiri'

puts "Limpando a tabela de filmes..."
Movie.destroy_all

url = "https://en.wikipedia.org/wiki/List_of_highest-grossing_superhero_films"
puts "Inciando o scraping da página: #{url}"

begin
  html = URI.open(url)
  doc = Nokogiri::HTML(html)

  # A tabela principal que nos interessa tem a classe 'wikitable'
  # Vamos capturar a primeira que aparece na página
  table = doc.at_css('table.wikitable')

  # Iterar sobre as linhas da tabela, ignorando a primeira (cabeçalhos)
  table.css('tr')[1..-1].each do |row|
    # Algumas linhas usam 'th' para o título do filme na Wikipedia, outras usam 'td'
    columns = row.css('td, th')
    
    # Garantir que a linha tem as colunas esperadas antes de processar
    next if columns.count < 6 

    # Na Wikipedia, as colunas são: 
    # 0: Rank | 1: Film | 2: Worldwide gross | 3: Year | 4: Superhero universe | 5: Distributor
    title = columns[1].text.strip
    gross_raw = columns[2].text.strip
    year_raw = columns[3].text.strip
    universe = columns[4].text.strip
    distributor = columns[5].text.strip

    # Limpeza de dados:
    # Remove o sinal de dólar, vírgulas e eventuais referências como [1] ou [a]
    worldwide_gross = gross_raw.gsub(/[^\d]/, '').to_i
    # Pega apenas os 4 primeiros caracteres para o ano, evitando lixo em formatações estranhas
    year = year_raw[0..3].to_i 

    Movie.create!(
      title: title,
      worldwide_gross: worldwide_gross,
      year: year,
      universe: universe,
      distributor: distributor
    )
  end

  puts "Scraping concluído com sucesso! #{Movie.count} filmes inseridos na base de dados."
rescue => e
  puts "Ocorreu um erro durante o scraping: #{e.message}"
end