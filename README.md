<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/osamingo/osamingo/output/github-snake-dark.svg" />
  <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/osamingo/osamingo/output/github-snake.svg" />
  <img alt="github contribution grid snake animation" width="100%" src="https://raw.githubusercontent.com/osamingo/osamingo/output/github-snake.svg" />
</picture>

### Open Source Contributions

47 merged pull requests across 26 repositories, plus a commit in the Go standard library.

| Project                                                                                             | Contribution                                                                                                          |
| --------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| [gqlgo/gqlgenc](https://github.com/gqlgo/gqlgenc)                                                   | Added an option to encode nil slices as empty arrays, normalized nil generate configs, and modernized the CI workflow |
| [k1LoW/gostyle](https://github.com/k1LoW/gostyle)                                                   | Documented the exclude-files configuration                                                                            |
| [goccy/bigquery-emulator](https://github.com/goccy/bigquery-emulator)                               | Applied command options from environment values                                                                       |
| [gofrs/uuid](https://github.com/gofrs/uuid)                                                         | Fixed the CI badge link                                                                                               |
| [auth0/go-jwt-middleware](https://github.com/auth0/go-jwt-middleware)                               | Fixed a panic caused by an unchecked type assertion on custom claims                                                  |
| [sony/sonyflake](https://github.com/sony/sonyflake)                                                 | Simplified the test suite and pinned stable Go versions in CI                                                         |
| [go-joe/slack-adapter](https://github.com/go-joe/slack-adapter)                                     | Migrated the Slack client from nlopes/slack to slack-go/slack                                                         |
| [mercari/go-emv-code](https://github.com/mercari/go-emv-code)                                       | Added test cases for the encoder and the CRC16 hash                                                                   |
| [golang/go](https://github.com/golang/go)                                                           | Fixed an outdated algorithm reference URL in `compress/flate`                                                         |
| [mercari/go-dnscache](https://github.com/mercari/go-dnscache)                                       | Simplified the loop control of the refresh goroutine                                                                  |
| [go-playground/validator](https://github.com/go-playground/validator)                               | Corrected the documented tag name for printable ASCII validation                                                      |
| [uber-go/zap](https://github.com/uber-go/zap)                                                       | Added an apex/log case to the logging benchmark suite                                                                 |
| [kelseyhightower/envconfig](https://github.com/kelseyhightower/envconfig)                           | Added `MustProcess`                                                                                                   |
| [tagomoris/fluent-plugin-secure-forward](https://github.com/tagomoris/fluent-plugin-secure-forward) | Fixed a typo in an SSL session log message                                                                            |

### Libraries

| Library                                              | Description                                                                         |
| ---------------------------------------------------- | ----------------------------------------------------------------------------------- |
| [jsonrpc](https://github.com/osamingo/jsonrpc)       | JSON-RPC 2.0 server for `net/http`                                                  |
| [checkdigit](https://github.com/osamingo/checkdigit) | Check digit algorithms (Luhn, Verhoeff, Damm) and calculators (ISBN, EAN, JAN, UPC) |
| [indigo](https://github.com/osamingo/indigo)         | Distributed unique ID generator built on Sonyflake, encoded in Base58               |
| [gosh](https://github.com/osamingo/gosh)             | Runtime statistics handler for Go services                                          |
| [shamoji](https://github.com/osamingo/shamoji)       | Word filtering                                                                      |
| [go-kenall](https://github.com/osamingo/go-kenall)   | Client for the kenall Japanese address API                                          |

`jsonrpc`, `checkdigit`, `indigo`, `gosh`, and `shamoji` are listed on [awesome-go](https://github.com/avelino/awesome-go).
