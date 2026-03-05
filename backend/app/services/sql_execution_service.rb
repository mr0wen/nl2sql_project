# Service responsável por executar consultas SQL de forma controlada e segura.
#
# Este tipo de serviço é especialmente útil em cenários onde consultas podem ser
# geradas dinamicamente (ex: por um LLM ou input externo).
#
# O principal objetivo aqui é garantir que apenas consultas de leitura sejam
# executadas, evitando qualquer modificação no banco de dados.
class SqlExecutionService
  # Lista de palavras-chave SQL que indicam operações de escrita ou alteração
  # estrutural no banco de dados.
  #
  # Essas operações são explicitamente bloqueadas para garantir que apenas
  # consultas de leitura sejam executadas.
  #
  # Exemplos bloqueados:
  # INSERT -> criação de registros
  # UPDATE -> alteração de registros
  # DELETE -> remoção de registros
  # DROP / ALTER / TRUNCATE / CREATE -> alterações estruturais
  # GRANT / REVOKE -> permissões de acesso
  FORBIDDEN_KEYWORDS = %w[INSERT UPDATE DELETE DROP ALTER TRUNCATE CREATE GRANT REVOKE].freeze

  # Inicializa o serviço com a query SQL recebida.
  #
  # to_s garante que qualquer valor recebido seja convertido para string,
  # evitando erros inesperados.
  #
  # strip remove espaços extras no início e fim da query.
  def initialize(sql)
    @sql = sql.to_s.strip
  end

  # Método principal do serviço.
  #
  # Fluxo:
  # 1. Valida a query recebida para garantir segurança
  # 2. Executa a query no banco
  def call
    validate_query!
    execute_query
  end

  private

  # Responsável por aplicar regras de segurança antes da execução da query.
  #
  # Esse método protege contra:
  # - Execução de queries de escrita
  # - Query stacking (múltiplas instruções SQL)
  # - Uso de comandos potencialmente perigosos
  def validate_query!
    # 1. Garante que a query começa obrigatoriamente com SELECT
    #
    # Isso impede execução de comandos como:
    # UPDATE users SET admin = true
    #
    # Regex:
    # \A -> início da string
    # \s* -> permite espaços antes do SELECT
    # i -> case insensitive
    unless @sql.match?(/\A\s*SELECT/i)
      raise StandardError, "Apenas consultas SELECT são permitidas por motivos de segurança."
    end

    # 2. Impede múltiplas instruções na mesma chamada.
    #
    # Isso evita ataques conhecidos como "SQL query stacking".
    #
    # Exemplo de ataque:
    # SELECT * FROM movies; DROP TABLE users;
    #
    # Ao bloquear o ponto e vírgula garantimos que apenas uma
    # instrução simples seja executada.
    if @sql.match?(/;/i)
      raise StandardError, "Múltiplas instruções SQL (uso de ponto e vírgula) não são permitidas."
    end

    # 3. Varredura contra palavras proibidas
    #
    # Mesmo que a query comece com SELECT, alguém poderia tentar
    # manipular a instrução com subqueries ou outras construções
    # maliciosas contendo operações proibidas.
    #
    # A regex usa:
    # \b -> boundary de palavra
    # para evitar falsos positivos dentro de outras palavras.
    if FORBIDDEN_KEYWORDS.any? { |kw| @sql.match?(/\b#{kw}\b/i) }
      raise StandardError, "A consulta contém operações não permitidas (modificação de dados)."
    end
  end

  # Executa a query no banco de dados.
  #
  # select_all executa a consulta e retorna um objeto
  # ActiveRecord::Result contendo:
  # - colunas
  # - linhas retornadas
  #
  # Convertendo para array com to_a obtemos uma estrutura
  # facilmente serializável para JSON.
  #
  # Exemplo de retorno:
  # [
  #   { "id" => 1, "title" => "Matrix" },
  #   { "id" => 2, "title" => "Inception" }
  # ]
  def execute_query
    result = ActiveRecord::Base.connection.select_all(@sql)
    result.to_a

  rescue ActiveRecord::StatementInvalid => e
    # Captura erros vindos diretamente do banco de dados.
    #
    # Exemplos comuns:
    # - coluna inexistente
    # - tabela inexistente
    # - erro de sintaxe SQL
    #
    # Retornamos uma mensagem controlada para evitar exposição
    # de detalhes internos ou stack traces do banco.
    raise StandardError, "Erro de sintaxe ou coluna inexistente: #{e.message}"
  end
end