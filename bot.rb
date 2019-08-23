require 'rubygems'

require 'expect'
require 'logger'
require 'open3'
require 'telegram/bot'
require 'pp'

load 'config.rb'

def split_command_botname(command)
  splitter_index = command.index('@') || command.length
  raw_command = command[0, splitter_index]
  bot_name = command[splitter_index + 1, command.length]
  [raw_command, bot_name]
end

def call_wf(options, bot)
  bot.logger.info("Calling wf with: wf #{options} --telegramoutput")
  `wf #{options} --telegramoutput`
end

# login to workflowy
def login_wf(bot)
  Open3.popen3('wf') do |i, o, e, t|
    o.expect('email: ', 5)
    i.puts "#{Config.config['workflowy']['username']}"
    o.expect('password: ', 5)
    i.puts "#{Config.config['workflowy']['password']}"
    i.close
  end
  bot.logger.info('workflowy login complete')
end

# /tree [depth <n>] [ids] [notes] [completed] (<alias/id>|root)
def handle_tree_command(text, bot)
  parsed_all_options = false
  rest = text
  run_command = 'tree 1 --hiddencompleted'
  until parsed_all_options
    arg, rest = rest.split(' ', 2)
    case arg
    when 'depth'
      # get num
      depth, rest = rest.split(' ', 2)
      bot.logger.info(depth)
      # replace because we ignore the standard 1
      run_command = run_command.gsub(/tree 1/, "tree #{depth}")
    when 'ids'
      run_command += ' --withid'
    when 'notes'
      run_command += ' --withnote'
    when 'completed'
      run_command.sub(' --hiddencompleted', '')
    else
      parsed_all_options = true
      # rejoin
      rest = (arg || '') + ' ' + (rest || '')
    end
  end

  return call_wf(run_command, bot) if rest == 'root'

  call_wf("#{run_command} --id=#{rest}", bot)
end


# /alias add / list / rm
def handle_alias_command(text, bot)
  blocked_alias_names = %w[depth ids notes completed top bottom]
  bot.logger.info(text.nil?)
  if text.nil?
    verb = 'list'
  else
    verb, name, id = text.split(' ')
  end

  case verb
  when 'add'
    # /alias add <name> <id>
    if blocked_alias_names.include?(name) || name.scan(/\D/).empty?
      return 'Please choose an alias that is not a bot keyword or a number'
    end

    call_wf("alias add --name=#{name} --id=#{id}", bot)
  when 'list'
    # /alias list
    call_wf('alias list', bot)
  when 'rm'
    # /alias rm <name>
    call_wf("alias remove --name=#{name}", bot)
  else
    "Please call the alias command with either 'add <name> <id>', 'list' or 'rm <name>'"
  end
end

# /add [top/bottom/<postion>] <parentnode/alias> <text>
# /addnote [top/bottom/<postion>] <parentnode/alias> <text> <note>
def handle_add_command(text, bot, withnote)
  bot.logger.info(withnote)
  run_command = 'capture'
  first_arg, rest = text.split(' ', 2)
  case first_arg
  when 'top'
    # prepend
    run_command += ' --priority=0'
  when 'bottom'
    # append
    run_command += ' --priority=1000'
  else
    if first_arg.scan(/\D/).empty?
      # number -> explicitly given position
      run_command += " --priority=#{first_arg.to_i}"
    else
      # rejoin
      rest = (first_arg || '') + ' ' + (rest || '')
    end
  end
  if withnote
    parentnode, text_and_note = rest.split(' ', 2)
    text_to_add, note = text_and_note.split('" "', 2)
    text_to_add = text_to_add[1, note.length] if text_to_add.start_with?('"')
    note = note[0, note.length - 1] if (note || '').end_with?('"')
    call_wf("#{run_command} --parentid=#{parentnode} --name=\"#{text_to_add}\" --note=\"#{note}\"", bot)
  else
    parentnode, text_to_add = rest.split(' ', 2)
    call_wf("#{run_command} --parentid=#{parentnode} --name=\"#{text_to_add}\"", bot)
  end
end

# determine wether we process further, command and text separation
def preprocess_message(message, bot)
  # ignore if message is not from you
  return [false, '', ''] if message.from.id != Config.config['user']['tg_id']

  command_data = message.entities.find { |entity| entity.type == 'bot_command'}
  return [false, '', ''] if command_data.nil? # message to bot without command

  if command_data.offset != 0
    bot.api.send_message(chat_id: message.chat.id, text: 'Please give bot command first in your message :)')
    return [false, '', '']
  end

  long_command = message.text[0, command_data.length]
  command, bot_name = split_command_botname(long_command)
  text = message.text[command_data.length + 1, message.text.length]

  # ignore message cause it was adressed to another bot
  return [false, '', ''] if !bot_name.nil? && bot_name != Config.config['bot']['username']

  [true, command, text]
end

if $PROGRAM_NAME == __FILE__

  Telegram::Bot::Client.run(Config.config['bot']['token'], logger: Logger.new($stderr)) do |bot|
    bot.logger.info('Bot has been started')
    login_wf(bot)

    bot.listen do |message|

      begin

        continue_processing, command, text = preprocess_message(message, bot)
        next unless continue_processing

        next if text.nil? && command != '/alias'

        reply = case command
                when '/start'
                  "Hello, #{message.from.first_name}"
                when '/stop'
                  "Bye, #{message.from.first_name}"
                when '/tree'
                  handle_tree_command(text, bot)
                when '/alias'
                  handle_alias_command(text, bot)
                when '/add'
                  handle_add_command(text, bot, false)
                when '/addnote'
                  hadle_add_command(text, bot, true)
                when '/wf'
                  # running commandline wf with just the plain given command
                  `wf #{text}`
                when '/help'
                  call_wf('--help')
                else
                  "I don't understand you :("
                end
        reply = 'reply was empty' if reply.empty?
        bot.api.send_message(chat_id: message.chat.id, text: reply.to_s[0, 1000])
      rescue Exception => ex
        bot.logger.info("Caugth exception: #{ex}")
      end
    end
  end

end
