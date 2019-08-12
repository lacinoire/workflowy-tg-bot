FROM timbru31/ruby-node:latest

RUN npm --global config set user root && \
    npm --global install workflowy-cli@latest

ENV PATH="/usr/local/bin:${PATH}"

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN gem install bundler:2.0.2
RUN bundle install

COPY . .

CMD ["ruby", "./bot.rb"]
