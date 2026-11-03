# Beta testing

Beta builds get new features a week or two before everyone else.

## Join

1. Open **Settings → General** and turn on **Get beta versions too**.
2. Monorail checks for betas along with normal releases and installs them the same way.
3. To leave, turn it off. You'll move to the next normal release when it comes out.

With Homebrew: `brew tap ashfordeOU/monorail https://github.com/ashfordeOU/monorail && brew install --cask monorail`, then turn on beta versions in
Settings. Monorail updates itself, so Homebrew doesn't need to.

## What we ask

- Use Monorail normally for a few days.
- Report anything odd with **Settings → Smart → Trust → Report a Problem…**. It fills in your Mac,
  macOS and Monorail versions.
- Keep anonymous usage counts on if you can. They show which features betas use and whether a
  beta crashes or uses more energy.

## Making a beta (maintainers)

Publish a GitHub release marked **pre-release** with a version like `1.7.0-beta.1`. Only Macs with
beta updates on will pick it up.
