# backend/Dockerfile
FROM ruby:3.3.0

# Instala dependências do sistema necessárias para o Rails e o PostgreSQL
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs

WORKDIR /app

# Copia os arquivos de dependência e instala as gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copia o resto da aplicação
COPY . .

# Expõe a porta do servidor Rails
EXPOSE 3000

# Comando padrão para iniciar o servidor
CMD ["bash", "-c", "rm -f tmp/pids/server.pid && bundle exec rails s -b '0.0.0.0'"]