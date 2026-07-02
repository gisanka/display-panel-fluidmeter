# Display Panel Fluidmeter

[![Release](https://github.com/gisanka/display-panel-fluidmeter/actions/workflows/release.yml/badge.svg?branch=main)](https://github.com/gisanka/display-panel-fluidmeter/actions/workflows/release.yml)

Display Panel Fluidmeter creates a blueprint book of display-panel fluid meters for the fluids in your current game.

Run one command and the mod generates a blueprint book containing one blueprint per real fluid prototype. Each blueprint contains a single display panel that shows the matching fluid icon, a colored 0-100% progress bar, and aligned percent text.

## Features

- Generates a blueprint book in-game from the currently loaded fluid prototypes.
- Creates one display-panel blueprint per visible, non-parameter fluid.
- Uses translated fluid names for blueprint labels when available.
- Colors each progress bar from the fluid prototype color.
- Keeps large generated books usable with Factorio's blueprint-book search. Press `CTRL+F` while browsing the book to find a fluid.
- Works with modded fluids because generation happens at runtime in the current save.

## Usage

Open the console and run:

```text
/fluidmeter-book
```

The mod requests localized fluid names first. For large modpacks this can take a short moment; the blueprint book is created in your cursor when the translations finish.

If your cursor cannot be cleared, empty your cursor and run the command again.

## Signal Input

Each generated display panel expects a circuit network signal for its own fluid:

- Signal type: `fluid`
- Signal name: the fluid shown by that blueprint
- Signal value: a percentage from `0` to `100`

For example, the water meter blueprint reads the `water` fluid signal and displays the corresponding percentage.

If you connect a panel directly to a storage tank, Factorio will provide the raw fluid amount, not a percentage. Add circuit logic to scale the tank contents to `0-100` before feeding the signal into the display panel.

*In Factorio 2.1, display panels can be connected directly to pipes. This can be useful for reading fluid segment fill levels without the need for additional tank-scaling logic.*

## Modpack Compatibility

The book is generated from the fluid prototypes loaded in the current game, so fluids added by other mods are included automatically.

This is useful for large modpacks. Pyanodons, for example, has hundreds of fluids; the generated book remains practical because blueprint labels are translated and searchable with `CTRL+F`.

## Limitations

- The mod creates blueprint books only when you run the command; it does not place meters automatically.
- Each blueprint contains one display panel.
- The display panel has 100 message entries. The generated scale covers `0-100`, with `49` skipped so `50` remains available within the display-panel limit.
- The input signal must already be scaled to percent.
- Hidden, parameter, and internal fluids are skipped.

## Commands

```text
/fluidmeter-book
```

Create a fluidmeter blueprint book in your cursor.

```text
/fluidmeter-reset
```

Reset pending localization requests for your player. This is a fallback command for unusual cases where translation requests remain pending.

## Development

Releases are automated with semantic-release and semantic-release-factorio. The generated release version is written to `info.json` during release.
