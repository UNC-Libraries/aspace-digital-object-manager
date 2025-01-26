# Digital Object Manager plugin

Adds an API endpoint that manages Aspace Digital Objects (DOs) based on submitted digital content data. "Management" of DOs means ensuring the digital content data is reflected in Aspace by, as needed, creating/deleting DOs and creating/deleting DO instances attached to the appropriate Archival Object (AO).

## Setup

In the ArchivesSpace `config.rb`:

- Add 'digital_object_manager' to the plugins entry
  - e.g. `AppConfig[:plugins] = ['local', 'lcnaf', 'digital_object_manager]`
- Optionally, add these commented-out default values to the config. Uncomment them
  if you want to change the value from the default.

  ```ruby
  # Aspace Digital Object Manager plugin config
  #AppConfig[:digital_object_manager_log] = '/opt/archivesspace/logs/digital_object_manager.log'
  #AppConfig[:digital_object_manager_log_level] = 'warn'
  ```

## Parameters

- source: ['cdm', 'dcr']
  - the type of DO you want to manage
- delete: ['none' (default), 'global']
  - 'global' means that managed DOs not found in the digital content data being submitted will be deleted. This means you must supply a complete set of digital content data for the given source
  - 'none' means that managed DOs not found in the digital content data being submitted will be left in place. You may submit an incomplete set of digital content data to get some specified DOs created/managed, without the manager deleting all of the DOs left out of your submission
- deletion_threshold: [`nil` (default), '1', '2', ...]
  - Sets a minimum record threshold such that if the submitted data does not contain at least that many records, no deletions or DO unlinking will be performed. This prevents the plugin from committing mass deletions in the event faulty/incomplete data is submitted.

NOTE: the repository number in the URL (e.g. ".../repositories/2/...") should be the repository you want to act on.

## Submitted data

Submitted data is expected to be in a utf-8-encoded csv with unix line endings and with headers.

Each source has certain required fields. Additional fields are allowed and will have no effect.

### Required fields

Required fields, explanations where needed, and examples.

- CDM:
  - **ref_id** - ref_id for the corresponding AO
    - 'fcee5fc2bb61effc8836498a8117b05d'
  - **cache_hookid** (or '**content_id**')
    - '01234_folder_3'
  - **collid** - the collection number, including any z modifiers
    - '01234-z'
  - **aspace_hookid**
    - '01234_folder_3'
- DCR:
  - **ref_id** - ref_id for the corresponding AO
    - 'fcee5fc2bb61effc8836498a8117b05d'
  - **uuid** (or '**content_id**') - the DCR Work UUID
    - 'b7b8be2b-ffd7-4f6d-9f1b-6cf5d71d5e4a'
  - **work_title** (or '**content_title**')
    - 'Folder 1: Letters, 1850'

Note that for CDM, the hookID:refID mapping file is a valid submission. That's the file produced by [ArchivesSpace_Script's](https://gitlab.lib.unc.edu/cappdev/ArchivesSpace_Scripts) `hookids/instance_to_hookid.rb`.

## Example shell usage

The example data files in `examples/` have faked digital content data. However, the ref_ids specified in those files are ref_ids that are seeded in archette's TEST database/repository, so the examples below will create DOs on those seeded archival objects. If you have overwritten/deleted the TEST repository, the examples will not create DOs since the specified AOs are missing.

### Authenticate

```sh
# fill in user name and password
echo "export TOKEN=$(curl -F password={USER_PASSWORD} http://localhost:8089/users/{USER}/login | jq '.session')" > .session
source .session
```

### Manage DCR DOs

```sh
curl \
  -H "Content-Type: text/csv" \
  -H "X-ArchivesSpace-Session: $TOKEN" \
  -X POST \
  --data-binary @examples/dcr_example.csv \
  "http://localhost:8089/repositories/1/digital_object_manager?source=dcr&delete=none"
```

### Manage CDM DOs

```sh
curl \
  -H "Content-Type: text/csv" \
  -H "X-ArchivesSpace-Session: $TOKEN" \
  -X POST \
  --data-binary @examples/cdm_example.csv \
  "http://localhost:8089/repositories/1/digital_object_manager?source=cdm&delete=none"
```

Formatting of the above examples is based off of the [jsonmodel_from_format](https://github.com/lyrasis/aspace-jsonmodel-from-format) plugin.

## Tests

Tests included here cover behavior wholly encapsulated in this plugin, but need to mock any Aspace integration. We don't run these tests in a proper ArchivesSpace build environment where we might test the fully integrated plugin.

Additional end-to-end type tests are located in our aspace-local plugin. They
rely on some "TEST" repository database seeding and API user/passwords.
