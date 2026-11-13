# Shifting Tides

<img width="1285" height="726" alt="image" src="https://github.com/user-attachments/assets/c0dd22b3-00fe-41e4-87d0-0bace82e7eb2" />

A turn-based grid puzzle about crossing a tidal coastline. Every action you take
advances a fixed tide clock by one tick, and the puzzle is reading the clock.

You can't touch the tide. It follows the same cycle every level, 0, 1, 2, 3, 2,
1 and round again, and a cell is dry only while its height is above the tide.
End a tick on a wet cell while on foot and you drown. Take every shell, reach
the goal, and get there before the wave, which lands on the level's Nth high
tide and is the only deadline there is. A wait is an action too: it costs a
tick and goes nowhere, and sometimes it is exactly what the route needs.

Each level has a par, the number of actions in its shortest solution. Winning
shows a card with your actions against par, and your best for the level is the
fewest you have won in. Finish a level to unlock the next.

## Play it

[occaras.itch.io/shifting-tides](https://occaras.itch.io/shifting-tides)

## Controls

Shifting Tides is played with the keyboard; the mouse also works on the level
select. Keys use physical key positions. Every row of this table is in the
in-game controls overlay too, so press `/` or `F1` on any screen to see the
list your build binds.

| Control | Keys |
| --- | --- |
| Step (one cell, four directions) | Arrow keys, `W` `A` `S` `D` |
| Wait | `Space`, `.` |
| Undo | `Z` |
| Restart | `R` |
| Menu | `Esc` |
| Confirm (title, level select) | `Enter`, Keypad `Enter`, `Space` |
| Mute or unmute music | `M` |
| Mute or unmute sound | `N` |
| Controls overlay | `/`, `F1` |
| Settings panel (music and sound volume) | `O` |

While the controls overlay or the settings panel is open, `Esc` closes it, as
the keys that opened it do. On the settings panel, Up and Down pick music or
sound and Left and Right turn it down or back up; `M` and `N` still mute.

## Run it from source

Open the project in Godot 4.7 and run the main scene, `scenes/main.tscn`.
