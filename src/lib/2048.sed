#!/bin/sed -rnf

:next

    # If the hold buffer contains something, append the hold buffer to
    # the pattern buffer so that we can use the existing board with the
    # new key-press.
    x
    /./{
        x
        G
        s/\n//
        b check-if-game-is-over
    }
    x


:seed-board

    # TODO: should be initially seeded with random positions
    # Seed initial positions:
    #
    # g a - c
    # - a - d
    # - a - e
    # - a - f
    #
    s/$/:ga-c:-a-d:-a-e:-a-f/


:check-if-game-is-over

    # The game is over when no more moves are possible. The simplest
    # way to check this is to perform a trial run through verical and
    # horizontal merges.

    #
    # In a dry-run.
    #

    # Already in a horizontal dry-run, which means no cells were merged.
    # Let's try a vertical dry-run instead.
    /^Ld/{
        s/^./D/
        b rotate-forward-if-necessary
    }

    # Already in a vertical dry-run, which means no cells were merged.
    # There are no moves left! Game over!
    /^Dd/b game-over

    #
    # Not in a dry-run.
    #

    # There's at least one cell open - continue!
    /-/b game-not-over

    # No cells available, let's see if a horizontal move is possible.
    # Set the "dry-run" flag (d).
    s/^(.)/Ld \1/
    b merge


:game-over

    # Aw, set a flag to indicate the game being over.
    s/$/ z/
    b output


:game-not-over

    # Yay! Let's continue!


:rotate-forward-if-necessary

    # If left or right was pressed, merge blocks without rotating.
    /^[LR]/b merge

    # Clockwise rotation:
    #
    #    abcd => miea
    #    efgh => njfb
    #    ijkl => okgc
    #    mnop => plhd
    #
    #    When expressed linearly:
    #
    #    abcd efgh ijkl mnop
    #    4    3    2    1    => miea
    #     4    3    2    1   => njfb
    #      4    3    2    1  => okgc
    #       4    3    2    1 => plhd

    # Generate the new order and place it after the existing order.
    s/:(.)...:(.)...:(.)...:(.).../& \4\3\2\1:/
    s/:.(.)..:.(.)..:.(.)..:.(.).. .*/&\4\3\2\1:/
    s/:..(.).:..(.).:..(.).:..(.). .*/&\4\3\2\1:/
    s/:...(.):...(.):...(.):...(.) .*/&\4\3\2\1/

    s/:....:....:....:.... /:/


:merge
    
    # Collapse spaces.
    s/-//g

    # Jump to next line to clear conditional jump state.
    t try-merge

    # Merge cells. We merge them in high-to-low order so that four
    # "2" cells become two "4" cells and not a single "8" cell.
    :try-merge

        s/kk/l/g
        s/jj/k/g
        s/ii/j/g
        s/hh/i/g
        s/gg/h/g
        s/ff/g/g
        s/ee/f/g
        s/dd/e/g
        s/cc/d/g
        s/bb/c/g
        s/aa/b/g

    #
    # If this is a dry-run AND a substitution was made, the game is not
    # over.
    #
    /^.d /{
        # If a merge was made, end the dry-run.
        t end-dry-run

        # Restore the board state from the hold buffer.
        G
        s/:.*\n//

        # Still a possibility that the game is over.
        b check-if-game-is-over

        :end-dry-run

            # Remove the dry-run flag
            s/^.d //
            
            # Restore the board state from the hold buffer.
            G
            s/:.*\n//
            
            # Continue game :)
            b game-not-over
    }


:pad

    # If right (or a rotated up), pad left. Otherwise, pad right.
    /^[RU]/b pad-left


:pad-right

    # Add an extra four dashes to the right of the line, then trim the
    # line to the left-most four characters.
    s/(:[^:]*)/\1----/g
    s/(:....)[^:]*/\1/g
    b rotate-backwards-if-necessary


:pad-left

    # Add an extra four dashes to the left of the line, then trim the
    # line to the right-most four characters.
    s/:([^:]*)/:----\1/g
    s/[^:]*(....)(:|$)/\1\2/g
    b rotate-backwards-if-necessary


:rotate-backwards-if-necessary

    # Don't rotate back if we didn't rotate in the first place.
    /^[LR]/b populate-empty-tile-if-necessary

    # Counter-clockwise rotation:
    #
    #    abcd => dhlp
    #    efgh => cgko
    #    ijkl => bfjn
    #    mnop => aeim
    #
    #    When expressed linearly:
    #
    #    abcd efgh ijkl mnop
    #       1    2    3    4 => dhlp
    #      1    2    3    4  => cgko
    #     1    2    3    4   => bfjn
    #    1    2    3    4    => aeim

    # Generate the new order and place it after the existing order.
    s/:...(.):...(.):...(.):...(.)/& \1\2\3\4:/
    s/:..(.).:..(.).:..(.).:..(.). .*/&\1\2\3\4:/
    s/:.(.)..:.(.)..:.(.)..:.(.).. .*/&\1\2\3\4:/
    s/:(.)...:(.)...:(.)...:(.)... .*/&\1\2\3\4/

    s/:....:....:....:.... /:/


:populate-empty-tile-if-necessary

    # An empty tile should be populated if the state of the board before
    # the move is different than the state of the board after the move.
    #
    # This is easy to check, since *before* state is still in the hold
    # buffer. To compare, we'll simply append the hold buffer to the
    # pattern buffer and see if the pattern buffer appears twice.
    
    # Append *before* state to *after* state (separated by a newline).
    G

    /((:....){4})\n\1/!{
        # Since the before/after board state differs, populate the first
        # (for now) empty tile with a '2' tile.
        # TODO: populate a random empty cell instead of the first cell.
        s/-/a/
    }

    # Remove the *before* state.
    s/\n.*//


:output

    # If the game is over, exit with a message.
    / z/{
        s/.*/\nNo more moves! Game over./
        p
        q
    }

    # Remove key press direction and random input.
    s/^[^:]*//

    # Copy board layout to hold buffer for next time.
    h

    # Replace tokens with real numbers.
    s/-/|____/g
    s/a/|___2/g
    s/b/|___4/g
    s/c/|___8/g
    s/d/|__16/g
    s/e/|__32/g
    s/f/|__64/g
    s/g/|_128/g
    s/h/|_256/g
    s/i/|_512/g
    s/j/|1024/g
    s/k/|2048/g
    s/l/|4096/g

    # Split board into multiple lines and draw borders.
    s/:/\n/g
    s/$/\n/
    s/\n/|&/2g
    s/\n/ ___________________&/

    # Output board.
    p