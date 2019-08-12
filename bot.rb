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

def call_wf(options)
  `wf #{options} --telegramoutput`
end

def wf_cli_help_text()
  "workflowy-cli API:
The commands currently available are:
   tree n                     print your workflowy nodes up to depth n (default: 2)
     [--id=<id/alias>]           print sub nodes under the <id> (default: whole tree)
     [--withnote]                print the note of nodes (default: false)
     [--hiddencompleted]         hide the completed lists (default: false)
     [--withid]                  print id of nodes (default: false)

   capture                    add something to a particular node
      --parentid=<id/alias>       36-digit uuid of parent (required) or defined alias
      --name=<str>                what to actually put on the node (required)
     [--priority=<int>]               0 as first child, 1 as second (default 0 (top))
                                      (use a number like 10000 for bottom)
     [--note=<str>]               a note for the node (default '')

   alias                      list all curretnly defined aliases

   alias add                  add new alias
      --id=<id>                   36-digit uuid to alias (required)
      --name=<alias>              name to give the alias (required)

   alias remove               remove existing alias
      --name=<str>                name to give the alias (required)

   common options             options to use on all commands
      [--telegramoutput]         format output to use in telegram bot"
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

if $PROGRAM_NAME == __FILE__

  Telegram::Bot::Client.run(Config.config['bot']['token'], logger: Logger.new($stderr)) do |bot|
    bot.logger.info('Bot has been started')
    login_wf(bot)

    bot.listen do |message|

      # ignore if message is not from you
      next if message.from.id != Config.config['user']['tg_id']

      command_data = message.entities.find { |entity| entity.type == 'bot_command'}
      next if command_data.nil? # message to bot without command

      if command_data.offset != 0
        bot.api.send_message(chat_id: message.chat.id, text: 'Please give bot command first in your message :)')
        next
      end

      long_command = message.text[0, command_data.length]
      command, bot_name = split_command_botname(long_command)

      text = message.text[command_data.length + 1, message.text.length]

      if !bot_name.nil? && bot_name != Config.config['bot']['username']
        # ignore message cause it was adressed to another bot
        next
      end

      case command
      when '/start'
        bot.api.send_message(chat_id: message.chat.id, text: "Hello, #{message.from.first_name}")
      when '/stop'
        bot.api.send_message(chat_id: message.chat.id, text: "Bye, #{message.from.first_name}")
      when '/tree'  # CALL ALWAYS WITH --telegramoutput
        # /tree alias
        #(depth standard 1, aber angebbar?)
        #(id standard aus, aber brauchen wir für alias)
        #(completed versteckt)
        #(withnote angebbar!)

      when '/alias'
        # /alias add <name> <id> , /alias list , /alias rm <name>
        verb, name, id = text.split(' ')
        case verb
        when 'add'
          reply = call_wf("add --name=#{name} --id=#{id}")
        when 'list'
          reply = call_wf("list")
        when 'remove'
          reply = call_wf("remove --name=#{name}")
        end
        bot.api.send_message(chat_id: message.chat.id, text: "#{reply[0, 1000]}")
      when '/add'
        # /add <parentnode/alias> <text>
        # /addnote <parentnode/alias> <text> <note>
        # option für append / prepend? oder nummer? (<- dann shortcut für append/prepend)
        # standard für alias festlegbar?
        # standard? prepend?
      when '/wf'
        # running commandline wf with just the plain given command
        reply = `wf #{text}`
        bot.logger.info(reply)
        bot.api.send_message(chat_id: message.chat.id, text: "#{reply[0, 1000]}")
      when '/help'
        bot.api.send_message(chat_id: message.chat.id, text: wf_cli_help_text)
      else
        bot.api.send_message(chat_id: message.chat.id, text: "I don't understand you :(")
      end
    end
  end

end
