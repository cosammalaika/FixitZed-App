## Services endpoint contract

- **Endpoint**: `GET /services` (customer app fetches with `per_page=200` via `HomeService.fetchServices`).
- **Required field**: expose `opted_in_fixers_count` (int) on each service record. Also return `has_fixers` (bool) = `opted_in_fixers_count > 0`. Client still tolerates legacy aliases but this pair is the contract.
- **Laravel query**:
  ```php
  // routes/api.php -> ServicesController@index (or equivalent)
  public function index()
  {
    $services = Service::query()
      ->with(['subcategory']) // existing relationships as needed
      ->withCount([
              'fixers as opted_in_fixers_count' => function ($query) {
                  $query->ready();
              },
          ])
          ->paginate(200);

      return ServiceResource::collection($services);
  }
  ```
- **Ready scope** (add to `Fixer` model if missing):
  ```php
  public function scopeReady($query)
  {
      return $query
          ->where('active', true)            // enabled
          ->where('approved', true)          // verified/approved
          ->whereNotNull('service_fixer.id'); // joined via pivot/relationship
          // Avoid relying on online flag unless it's reliable.
  }
  ```
- **Resource/transformer**: include both `opted_in_fixers_count` and `has_fixers` in `ServiceResource::toArray()` (`'has_fixers' => $this->opted_in_fixers_count > 0`).
- **Feature test**: add a test that seeds two services, attaches an approved/active fixer to one via the pivot, calls `GET /services`, and asserts: (a) JSON has `opted_in_fixers_count` for each service, (b) counts match, (c) `has_fixers` true only for the attached service.
- **Edge cases**: if the count cannot be computed, still return `opted_in_fixers_count: 0` and `has_fixers: false` so the client shows "No fixers yet" instead of an unknown state.
