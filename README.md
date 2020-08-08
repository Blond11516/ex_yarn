# ExYarn

This is a simple library for parsing [Yarn](https://classic.yarnpkg.com/en/) lockfiles. This is currently a mostly direct port of Yarn's [own parser](https://github.com/yarnpkg/yarn/blob/master/src/lockfile/parse.js), so it's very imperative-like in many places. I do plan to improve this and make better use of Elixir and OTP's features and ecosystem in the future.

**Note on performance:** This library was built in part as a learning exercise and therefore does not necessarily apply the best possible practices and tools when it comes to code quality and performance. If performance is important to you, I recommend using Dorgan's library ([hex.pm](https://hex.pm/packages/yarn_parser), [Github](https://github.com/doorgan/yarn_parser)), which uses [NimbleParsec](https://hexdocs.pm/nimble_parsec/NimbleParsec.html) for better performance.

## Installation

The package can be installed by adding `ex_yarn` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_yarn, "~> 0.3.0"}
  ]
end
```

## Documentation

Documentation is generated with [ExDoc](https://github.com/elixir-lang/ex_doc) and is published at [https://hexdocs.pm/ex_yarn](https://hexdocs.pm/ex_yarn).

## TODOs

- [x] Write documentation.
- [ ] Wrap the parser's output in a struct to make actual usage of the library easier.
- [ ] Improve code quality (this will obviously be an ongoing goal, but credo should at least run without errors for this to be considered "completed").
- [ ] Consider using [NimbleParsec](https://hexdocs.pm/nimble_parsec/NimbleParsec.html) to replace the parser for better maintainability and performance.
