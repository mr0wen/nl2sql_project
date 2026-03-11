import { useState, useRef, useEffect } from 'react';
import { Send, Terminal, Database, Loader2, GitBranch, Sparkles } from 'lucide-react';

// Tipagem para as mensagens do chat
type Message = {
  id: number;
  role: 'user' | 'assistant';
  content: string;
  sql?: string | null;
  data?: any[];
  isError?: boolean;
};

function App() {
  const [prompt, setPrompt] = useState('');
  const [version, setVersion] = useState<'v1' | 'v2'>('v2'); // Controle de Fase
  const [messages, setMessages] = useState<Message[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // Auto-scroll para a última mensagem
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  // Nova função para lidar com a troca de base de dados (UX aprimorado)
  const handleVersionChange = (newVersion: 'v1' | 'v2') => {
    if (version === newVersion) return; // Evita re-render se clicar na mesma versão
    setVersion(newVersion);
    setMessages([]); // Limpa a tela de consultas
    setPrompt(''); // Limpa o input de texto
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!prompt.trim()) return;

    const userMessage: Message = { id: Date.now(), role: 'user', content: prompt };
    setMessages((prev) => [...prev, userMessage]);
    setPrompt('');
    setIsLoading(true);

    try {
      const response = await fetch('http://localhost:3000/api/v1/queries', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ question: userMessage.content, version }),
      });

      const result = await response.json();

      // Interceptando o Rate Limit (Erro 429) do Gemini
      if (response.status === 429 || (result.error && result.error.includes('429'))) {
        throw new Error('⚠️ Limite diário da Inteligência Artificial atingido. A cota da API gratuita foi totalmente consumida. Por favor, retorne amanhã ou configure uma nova chave de acesso.');
      }

      if (!response.ok) throw new Error(result.error || 'Erro desconhecido ao processar query');

      const assistantMessage: Message = {
        id: Date.now() + 1,
        role: 'assistant',
        content: `Aqui está o resultado da sua consulta (utilizando a arquitetura ${version.toUpperCase()}):`,
        sql: result.sql || result.sql_generated, 
        data: result.data,
      };
      
      setMessages((prev) => [...prev, assistantMessage]);
    } catch (error: any) {
      setMessages((prev) => [
        ...prev,
        { id: Date.now() + 1, role: 'assistant', content: error.message, isError: true },
      ]);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="flex flex-col h-screen bg-gray-900 text-gray-100 font-sans">
      
      {/* Header com Toggle de Versão */}
      <header className="flex items-center justify-between p-4 bg-gray-800 border-b border-gray-700 shadow-sm">
        <div className="flex items-center">
          <Database className="w-6 h-6 mr-3 text-emerald-400" />
          <h1 className="text-xl font-semibold">Assistente NL2SQL</h1>
        </div>
        
        {/* Toggle UI */}
        <div className="flex items-center bg-gray-900 rounded-lg p-1 border border-gray-700">
          <GitBranch className="w-4 h-4 mr-2 text-gray-500 ml-2" />
          <button
            onClick={() => handleVersionChange('v1')}
            className={`px-3 py-1.5 text-xs font-medium rounded-md transition-all duration-300 ${
              version === 'v1' ? 'bg-gray-700 text-white shadow-md transform scale-105' : 'text-gray-400 hover:text-gray-200'
            }`}
          >
            Fase 1 (Flat)
          </button>
          <button
            onClick={() => handleVersionChange('v2')}
            className={`px-3 py-1.5 text-xs font-medium rounded-md transition-all duration-300 ${
              version === 'v2' ? 'bg-gray-700 text-white shadow-md transform scale-105' : 'text-gray-400 hover:text-gray-200'
            }`}
          >
            Fase 2 (Relacional)
          </button>
        </div>
      </header>

      {/* Área do Chat */}
      <main className="flex-1 overflow-y-auto p-4 md:p-8 space-y-6">
        
        {/* Mensagem de Boas-Vindas Dinâmica (Muda de acordo com a Versão) */}
        {messages.length === 0 && (
          <div className="flex flex-col items-center justify-center h-full text-center px-4 animate-in fade-in duration-500">
            <div className="p-4 bg-gray-800 rounded-full mb-6 border border-gray-700 shadow-lg">
              <Sparkles className="w-12 h-12 text-emerald-400 opacity-80" />
            </div>
            
            {version === 'v1' ? (
              <div className="max-w-md space-y-4">
                <h2 className="text-2xl font-bold text-gray-200">Base Plana (Tabela Única)</h2>
                <p className="text-gray-400">
                  Você está consultando a base de dados contendo os filmes de super-heróis de maior bilheteria.
                </p>
                <div className="mt-6 inline-block bg-emerald-900/30 border border-emerald-800/50 rounded-lg p-4">
                  <p className="text-xs font-semibold text-emerald-500 uppercase tracking-wider mb-2">Exemplo de pergunta:</p>
                  <p className="text-sm text-emerald-300 italic">"Quais são os 3 filmes com maior bilheteria da Marvel?"</p>
                </div>
              </div>
            ) : (
              <div className="max-w-md space-y-4">
                <h2 className="text-2xl font-bold text-gray-200">Base Relacional (IMDb Top 1000)</h2>
                <p className="text-gray-400">
                  Você está consultando um banco de dados complexo contendo múltiplos relacionamentos (JOINs) entre filmes, diretores, atores e gêneros.
                </p>
                <div className="mt-6 inline-block bg-emerald-900/30 border border-emerald-800/50 rounded-lg p-4">
                  <p className="text-xs font-semibold text-emerald-500 uppercase tracking-wider mb-2">Exemplo de pergunta:</p>
                  <p className="text-sm text-emerald-300 italic">"Quais filmes foram dirigidos por Christopher Nolan que têm Leonardo DiCaprio no elenco?"</p>
                </div>
              </div>
            )}
          </div>
        )}

        {/* ... Restante do código de renderização das mensagens se mantém igual ... */}
        {messages.map((msg) => (
          <div key={msg.id} className={`flex max-w-4xl mx-auto ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
            <div className={`rounded-lg p-5 w-full md:w-4/5 ${msg.role === 'user' ? 'bg-gray-800 border border-gray-700 shadow-md' : 'bg-transparent'}`}>
              
              <div className="flex items-center mb-3 text-sm font-medium">
                {msg.role === 'user' ? (
                  <span className="text-blue-400">Você</span>
                ) : (
                  <span className={msg.isError ? 'text-red-400' : 'text-emerald-400'}>Assistente</span>
                )}
              </div>

              <p className="mb-4 text-gray-200 leading-relaxed">{msg.content}</p>

              {msg.sql && (
                <div className="mb-4 rounded-md bg-gray-950 border border-gray-800 overflow-hidden shadow-inner">
                  <div className="flex items-center bg-gray-800 px-4 py-2 text-xs text-gray-400">
                    <Terminal className="w-4 h-4 mr-2" /> PostgreSQL
                  </div>
                  <pre className="p-4 text-sm font-mono text-emerald-300 overflow-x-auto whitespace-pre-wrap">
                    <code>{msg.sql}</code>
                  </pre>
                </div>
              )}

              {msg.data && msg.data.length > 0 && (
                <div className="overflow-x-auto rounded-md border border-gray-700 bg-gray-800 shadow-sm">
                  <table className="min-w-full text-left text-sm">
                    <thead className="bg-gray-900 border-b border-gray-700 text-gray-300">
                      <tr>
                        {Object.keys(msg.data[0]).map((key) => (
                          <th key={key} className="px-4 py-3 font-medium uppercase tracking-wider">{key}</th>
                        ))}
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-700">
                      {msg.data.map((row, i) => (
                        <tr key={i} className="hover:bg-gray-700/50 transition-colors">
                          {Object.values(row).map((val: any, j) => (
                            <td key={j} className="px-4 py-3 text-gray-300">{String(val)}</td>
                          ))}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}

              {msg.data && msg.data.length === 0 && !msg.isError && (
                <div className="p-4 border border-yellow-700 bg-yellow-900/20 text-yellow-500 rounded-md text-sm">
                  A consulta foi executada com sucesso, mas não retornou nenhum resultado do banco de dados.
                </div>
              )}
            </div>
          </div>
        ))}
        
        {isLoading && (
          <div className="flex max-w-4xl mx-auto justify-start animate-pulse">
            <div className="flex items-center space-x-3 text-gray-400 p-5">
              <Loader2 className="w-5 h-5 animate-spin text-emerald-500" />
              <span>Analisando a estrutura do banco e gerando query SQL...</span>
            </div>
          </div>
        )}
        <div ref={messagesEndRef} />
      </main>

      {/* Área de Input Fixa */}
      <footer className="p-4 bg-gray-800 border-t border-gray-700 shadow-[0_-4px_6px_-1px_rgba(0,0,0,0.1)]">
        <div className="max-w-4xl mx-auto relative">
          <form onSubmit={handleSubmit} className="relative flex items-center">
            <input
              type="text"
              value={prompt}
              onChange={(e) => setPrompt(e.target.value)}
              disabled={isLoading}
              placeholder={version === 'v1' ? "Pergunte sobre os filmes de super-heróis..." : "Pergunte sobre o IMDb Top 1000..."}
              className="w-full bg-gray-900 border border-gray-600 rounded-xl py-4 pl-5 pr-14 text-gray-100 focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:border-emerald-500 disabled:opacity-50 transition-all shadow-inner"
            />
            <button
              type="submit"
              disabled={isLoading || !prompt.trim()}
              className="absolute right-2 p-2 bg-emerald-600 hover:bg-emerald-500 text-white rounded-lg disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              <Send className="w-5 h-5" />
            </button>
          </form>
          <div className="text-center mt-3 text-xs text-gray-500 flex justify-center items-center space-x-1">
            <span>A IA pode cometer erros.</span>
            <span className="hidden sm:inline">•</span>
            <span>O motor de segurança impede comandos destrutivos (DROP, DELETE).</span>
          </div>
        </div>
      </footer>
    </div>
  );
}

export default App;