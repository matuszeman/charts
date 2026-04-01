# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code ONLY in this folder and all subfolders.
Skills: Load from `../.claude`

# Purpose

This folder contains integration tests for the `idp-app` and `idp-app-config` charts.

# Structure

- `CHART/Chart.yaml` — depends on `idp-app` (aliased as `app`) and `idp-app-config` (imports its `global` values)
- `CHART/values.yaml` — minimal values exercising the combined chart
- `CHART/tests` — helm unittest folder

## Notes

- The chart uses `file://` repository paths, so `helm dep up` must be re-run any time the local `idp-app` or `idp-app-config` charts change.
