# Event naming

- Event names are lowercase letters, digits, dots and underscores, start with a letter, and are at most 64 characters: `signup.completed`, `checkout.started`.
- Use `area.action` in the past tense for things that happened.
- Property keys are lowercase snake_case, at most 40 characters, at most 40 properties per event.
- Property values are a string (up to 256 characters), number, boolean or null. No nested objects or lists.
- Keys that name money are rejected on the device and on the server: amount, fee, rate, price, balance, revenue, volume, usd, total, cost, salary, alone or as a word inside the key (`order_total`, `fee_usd`). Words that merely contain those letters, such as `feedback` or `migrated`, are fine. FT.Engage tracks people and behaviour, not money.
- Do not put personal data such as names, emails or phone numbers in event names or properties.
