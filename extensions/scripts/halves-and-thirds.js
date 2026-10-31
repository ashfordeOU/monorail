// Two quick palette commands: everything in halves, or in thirds.
monorail.addCommand("All slides in halves", () => monorail.setWidths(Array(9).fill(0.5)))
monorail.addCommand("All slides in thirds", () => monorail.setWidths(Array(9).fill(1 / 3)))
