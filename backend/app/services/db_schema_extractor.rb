# Service object responsável por extrair informações do schema do banco
# de dados de forma controlada.
#
# Esse tipo de classe normalmente é utilizado para fornecer contexto
# para ferramentas externas (ex: LLMs que geram SQL dinamicamente).
#
# A principal preocupação aqui é SEGURANÇA: evitar expor todo o schema
# do banco para o modelo ou para qualquer outro consumidor externo.
class DbSchemaExtractor
  # O método agora aceita a versão da arquitetura (:v1 ou :v2)
  # O default é :v2, garantindo compatibilidade.
  def self.call(version: :v2)
    schema_info = []
    relationships = ""

    # Lista explícita de tabelas que podem ser expostas (Allowlist).
    # Evitamos que informações sensíveis sejam acidentalmente incluídas.
    if version == :v1
      # Fase 1: Arquitetura Flat (Tabela Única)
      allowed_tables = ['movies']
    else
      # Fase 2: Arquitetura Relacional (Múltiplas Tabelas em Português)
      allowed_tables = [
        'filmes', 'atores', 'diretores', 'generos', 
        'classificacao_indicativa', 'filmes_atores', 'filmes_generos'
      ]
      
      # O PULO DO GATO para a Fase 2:
      # Modelos fundacionais precisam de dicas explícitas sobre as chaves
      # estrangeiras (Foreign Keys) para não alucinarem conexões incorretas.
      relationships = <<~RELATIONS
        
        Relacionamentos (Foreign Keys) para construção de JOINs:
        - filmes.diretor_id = diretores.id
        - filmes.classificacao_indicativa_id = classificacao_indicativa.id
        - filmes_atores.filme_id = filmes.id
        - filmes_atores.ator_id = atores.id
        - filmes_generos.filme_id = filmes.id
        - filmes_generos.genero_id = generos.id
      RELATIONS
    end

    # Itera sobre cada tabela permitida e extrai suas colunas
    allowed_tables.each do |table_name|
      # ActiveRecord fornece acesso ao schema via connection.columns.
      # Isso retorna objetos ActiveRecord::ConnectionAdapters::Column
      columns = ActiveRecord::Base.connection.columns(table_name).map do |col|
        # Formata cada coluna no formato: nome_da_coluna (tipo_sql)
        "#{col.name} (#{col.sql_type})"
      end

      # Constrói uma representação simples da tabela e suas colunas.
      schema_info << "Tabela: #{table_name} | Colunas: #{columns.join(', ')}"
    end

    # Retorna todas as tabelas concatenadas em uma única string,
    # separadas por quebra de linha, anexando as regras de JOIN (se houver).
    schema_info.join("\n") + "\n" + relationships
  end
end