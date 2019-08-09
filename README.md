# workflowy-tg-bot
A Telegram bot to add stuff to Workflowy ✌🏼🥰

Currently enables you to run the [`opusfluxus`](https://github.com/malcolmocean/opusfluxus) tool through a Telegram bot 😊

Add your API tokens / Telegram User Id / Workflowy Login in [`config.yml`](config.yml) and then run with with [Docker](https://docs.docker.com/get-started/):
``` console
docker build -t wfbot .
```
``` console
docker run wfbot
```

You can find a command overview in [`bot-commands.txt`](bot-commands.txt), which you can also use to configure the command list in the [BotFather](https://core.telegram.org/bots#3-how-do-i-create-a-bot).
