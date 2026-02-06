# ENCORE builder

## Translation workflow

- User-facing QML strings are wrapped with `qsTr(...)`.
- Translation source files are stored under `i18n/` (for example `i18n/app_ru.ts`).
- To refresh `.ts` entries after changing UI text, run the CMake target:

```bash
cmake --build <build_dir> --target translations_update
```

This target calls `lupdate` when the tool is available in the environment.
