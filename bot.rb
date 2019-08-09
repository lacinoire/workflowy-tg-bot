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

if $PROGRAM_NAME == __FILE__

  Telegram::Bot::Client.run(Config.config['bot']['token'], logger: Logger.new($stderr)) do |bot|
    bot.logger.info('Bot has been started')

    # login to workflowy
    Open3.popen3('wf') do |i, o, e, t|
      o.expect('email: ', 5)
      i.puts "#{Config.config['workflowy']['username']}"
      o.expect('password: ', 5)
      i.puts "#{Config.config['workflowy']['password']}"
      i.close
      bot.logger.info(o.read)
    end

    # `wf`
    # `#{Config.config['workflowy']['username']}`
    # output = `#{Config.config['workflowy']['password']}`
    # bot.logger.info(output)
    bot.logger.info('workflowy login complete')

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
      when '/wf'
        # running commandline wf with just the plain given command
        reply = `wf #{text}`
        bot.logger.info(reply)
        bot.api.send_message(chat_id: message.chat.id, text: "#{reply[0, 1000]}")
      when '/help'
        bot.api.send_message(chat_id: message.chat.id, text: "opusfluxus CLI API:
          tree n             print your workflowy nodes up to depth n (default: 2)
            [--id=<id>]          print sub nodes under the <id> (default: whole tree)
            [--withnote]         print the note of nodes (default: false)
            [--hiddencompleted]  hide the completed lists (default: false)
            [--withid]           print id of nodes (default: false)
        
          capture            add something to a particular node
             --parentid=<id>      <36-digit uuid of parent> (required)
             --name=<str>         what to actually put on the node
            [--priority=#]        0 as first child, 1 as second (default 0 (top))
                                      (use a number like 10000 for bottom)
            [--note=<str>]        a note for the node (default '')")
      else
        bot.api.send_message(chat_id: message.chat.id, text: "I don't understand you :(")
      end
    end
  end

end
