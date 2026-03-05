# Service object responsável por extrair informações do schema do banco
# de dados de forma controlada.
#
# Esse tipo de classe normalmente é utilizado para fornecer contexto
# para ferramentas externas (ex: LLMs que geram SQL dinamicamente).
#
# A principal preocupação aqui é SEGURANÇA: evitar expor todo o schema
# do banco para o modelo ou para qualquer outro consumidor externo.
class DbSchemaExtractor
  def self.call
    # Lista explícita de tabelas que podem ser expostas.
    #
    # Usamos uma allowlist ao invés de buscar todas as tabelas do banco,
    # evitando que informações sensíveis (ex: users, payments, api_keys)
    # sejam acidentalmente incluídas no contexto enviado ao LLM.
    #
    # Isso também ajuda a manter o prompt menor e mais focado.
    allowed_tables = ['movies']

    # Array que irá acumular a representação textual do schema
    # de cada tabela permitida.
    schema_info = []

    # Itera sobre cada tabela permitida e extrai suas colunas
    allowed_tables.each do |table_name|
      # ActiveRecord fornece acesso ao schema via connection.columns.
      # Isso retorna objetos ActiveRecord::ConnectionAdapters::Column
      # contendo metadados sobre cada coluna.
      columns = ActiveRecord::Base.connection.columns(table_name).map do |col|
        # Formata cada coluna no formato:
        # nome_da_coluna (tipo_sql)
        #
        # Exemplo:
        # id (integer)
        # title (varchar)
        # release_year (integer)
        "#{col.name} (#{col.sql_type})"
      end

      # Constrói uma representação simples da tabela e suas colunas.
      #
      # Esse formato textual é útil para ser inserido diretamente em
      # prompts de LLM ou logs de inspeção.
      #
      # Exemplo de saída:
      # "Tabela: movies | Colunas: id (integer), title (varchar), year (integer)"
      schema_info << "Tabela: #{table_name} | Colunas: #{columns.join(', ')}"
    end

    # Retorna todas as tabelas concatenadas em uma única string,
    # separadas por quebra de linha.
    #
    # Exemplo final:
    #
    # Tabela: movies | Colunas: id (integer), title (varchar)
    # Tabela: directors | Colunas: id (integer), name (varchar)
    schema_info.join("\n")
  end
end