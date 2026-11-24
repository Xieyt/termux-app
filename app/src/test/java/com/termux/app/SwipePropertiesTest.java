package com.termux.app;

import com.termux.shared.termux.settings.properties.TermuxPropertyConstants;

import org.junit.Assert;
import org.junit.Test;

/** Guards for the fork's horizontal swipe feature (FORK.md §2.A). */
public class SwipePropertiesTest {

    /**
     * {@code SharedProperties#loadPropertiesFromDisk()} only keeps keys named in
     * {@code TERMUX_APP_PROPERTIES_LIST}. A swipe key missing from it compiles, loads without a
     * warning, and silently reads as unset, so swipes would never fire.
     */
    @Test
    public void swipeKeysAreInTheLoadedPropertiesList() {
        Assert.assertTrue(TermuxPropertyConstants.TERMUX_APP_PROPERTIES_LIST
            .contains(TermuxPropertyConstants.KEY_SWIPE_LEFT_SEQUENCE));
        Assert.assertTrue(TermuxPropertyConstants.TERMUX_APP_PROPERTIES_LIST
            .contains(TermuxPropertyConstants.KEY_SWIPE_RIGHT_SEQUENCE));
    }

}
