# @ft-engage/contracts

The public wire format for FT.Engage: JSON Schema 2020-12 for events, batches and device registration, with valid and invalid fixtures.

```js
import { validateEvent } from '@ft-engage/contracts';

validateEvent({ eventId: 'evt_00000001', name: 'app.opened', installId: 'inst_00000001', at: new Date().toISOString() });
```

The schemas are the source of truth. The Dart SDK and the server both test against them.
