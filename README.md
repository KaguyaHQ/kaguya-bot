# Kaguyabot

Kaguyabot is a Reddit bot that replies to book mentions with rich book data powered by [Kaguya](https://kaguya.io) — a modern, independent alternative to Goodreads.

It supports both quick replies and full book previews depending on how the book is summoned.

---

## 🧠 How It Works

Mention a book using single or double braces:

- `{The Hobbit by J.R.R. Tolkien}` → short reply with title, author, and Kaguya link
- `{{Dark Matter by Blake Crouch}}` → long reply with full description + metadata

Example reply:

I found: Dark Matter by Blake Crouch
📖 340 pages • 📆 2016
🏷️ sci-fi, multiverse, thriller

    "Are you happy with your life?"

🔗 https://kaguya.io/books/dark-matter


---

## ✨ Features

- 🧠 Intelligent parsing of book summons in Reddit comments
- ⚡ Uses the Kaguya GraphQL API for fast, modern book data
- ✅ Skips duplicates using persistent tracking
- 💬 Clean Markdown replies optimized for Reddit
- 🔧 Built in Elixir with a simple, reliable architecture

---

## 🚀 Getting Started

Clone the repo and install dependencies:

```bash
git clone https://github.com/KaguyaHQ/kaguya-bot.git
cd kaguya-bot
mix deps.get

Set up your .env file with Reddit credentials:

REDDIT_CLIENT_ID=your_client_id
REDDIT_SECRET=your_secret
REDDIT_USERNAME=your_bot_username
REDDIT_PASSWORD=your_bot_password
REDDIT_USER_AGENT=kaguyabot:v0.1.0 (by /u/yourusername)

Then run the bot:

mix run --no-halt
```

🛠️ Configuration

    Subreddit is currently hardcoded to "kaguya" (change in CommentPoller)

    Uses a Postgres database to track handled comments

    Supports microsecond-precision timestamps for event logging

📄 License

MIT — free for personal and commercial use.
Built with love for readers. 🕊