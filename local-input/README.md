# Local input (gitignored)

Place sensitive source files here. **Never commit** raw CSVs that contain personal information.

## Past clubs master list

Required file:

`JFSS_Official_Clubs_Masterlist_2025-2026.csv`

Generate the sanitized seed migration:

```bash
node scripts/generate-past-clubs-seed.mjs
```

The generator:

- expects **84** named source rows
- writes **83** canonical club records after the F.A.C.E. / Fraser Aces merge
- stops with an error if counts do not match
- never imports former leader contacts or personal emails

To generate only the 9 clubs added from `Clubs_list_past.csv` (for databases that already ran the original seed):

```bash
node scripts/generate-past-clubs-seed.mjs --additional-only
```
