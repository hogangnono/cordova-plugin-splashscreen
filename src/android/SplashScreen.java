/*
       Licensed to the Apache Software Foundation (ASF) under one
       or more contributor license agreements.  See the NOTICE file
       distributed with this work for additional information
       regarding copyright ownership.  The ASF licenses this file
       to you under the Apache License, Version 2.0 (the
       "License"); you may not use this file except in compliance
       with the License.  You may obtain a copy of the License at

         http://www.apache.org/licenses/LICENSE-2.0

       Unless required by applicable law or agreed to in writing,
       software distributed under the License is distributed on an
       "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
       KIND, either express or implied.  See the License for the
       specific language governing permissions and limitations
       under the License.
*/

package org.apache.cordova.splashscreen;

import android.app.Dialog;
import android.content.Context;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Handler;
import android.view.View;
import android.view.WindowManager;
import android.widget.ImageView;

import com.hogangnono.hogangnono.R;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.LOG;
import org.json.JSONArray;
import org.json.JSONException;

import java.io.File;

public class SplashScreen extends CordovaPlugin {
    private static final String LOG_TAG = "SplashScreen";
    private static final boolean HAS_BUILT_IN_SPLASH_SCREEN = false;
    private static final int DEFAULT_SPLASHSCREEN_DURATION = 3000;
    private static final int DEFAULT_FADE_DURATION = 500;
    private static Dialog splashDialog;
    private static boolean firstShow = true;
    private static boolean lastHideAfterDelay; // https://issues.apache.org/jira/browse/CB-9094

    /**
     * Remember last device orientation to detect orientation changes.
     */
    private int orientation;

    // Helper to be compile-time compatible with both Cordova 3.x and 4.x.
    private View getView() {
        try {
            return (View)webView.getClass().getMethod("getView").invoke(webView);
        } catch (Exception e) {
            return (View)webView;
        }
    }

    private int getSplashId() {
        int layoutId = 0;
        String splashResource = preferences.getString("SplashScreen", "screen");
        if (splashResource != null) {
            layoutId = cordova.getActivity().getResources().getIdentifier(splashResource, "layout", cordova.getActivity().getClass().getPackage().getName());
            if (layoutId == 0) {
                layoutId = cordova.getActivity().getResources().getIdentifier(splashResource, "layout", cordova.getActivity().getPackageName());
            }
        }
        return layoutId;
    }

    @Override
    protected void pluginInitialize() {
        if (HAS_BUILT_IN_SPLASH_SCREEN) {
            return;
        }
        // Make WebView invisible while loading URL
        // CB-11326 Ensure we're calling this on UI thread
        cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                getView().setVisibility(View.INVISIBLE);
            }
        });

        // Save initial orientation.
        orientation = cordova.getActivity().getResources().getConfiguration().orientation;

        if (firstShow) {
            boolean autoHide = preferences.getBoolean("AutoHideSplashScreen", true);
            showSplashScreen(autoHide);
        }

        if (preferences.getBoolean("SplashShowOnlyFirstTime", true)) {
            firstShow = false;
        }
    }

    /**
     * Shorter way to check value of "SplashMaintainAspectRatio" preference.
     */
    private boolean isMaintainAspectRatio () {
        return preferences.getBoolean("SplashMaintainAspectRatio", false);
    }

    private int getFadeDuration () {
        int fadeSplashScreenDuration = preferences.getBoolean("FadeSplashScreen", true) ?
            preferences.getInteger("FadeSplashScreenDuration", DEFAULT_FADE_DURATION) : 0;

        if (fadeSplashScreenDuration < 30) {
            // [CB-9750] This value used to be in decimal seconds, so we will assume that if someone specifies 10
            // they mean 10 seconds, and not the meaningless 10ms
            fadeSplashScreenDuration *= 1000;
        }

        return fadeSplashScreenDuration;
    }

    @Override
    public void onPause(boolean multitasking) {
        if (HAS_BUILT_IN_SPLASH_SCREEN) {
            return;
        }
        // hide the splash screen to avoid leaking a window
        this.removeSplashScreen(true);
    }

    @Override
    public void onDestroy() {
        if (HAS_BUILT_IN_SPLASH_SCREEN) {
            return;
        }
        // hide the splash screen to avoid leaking a window
        this.removeSplashScreen(true);
        // If we set this to true onDestroy, we lose track when we go from page to page!
        //firstShow = true;
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        if (action.equals("hide")) {
            cordova.getActivity().runOnUiThread(new Runnable() {
                public void run() {
                    webView.postMessage("splashscreen", "hide");
                }
            });
        } else if (action.equals("show")) {
            cordova.getActivity().runOnUiThread(new Runnable() {
                public void run() {
                    webView.postMessage("splashscreen", "show");
                }
            });
        } else {
            return false;
        }

        callbackContext.success();
        return true;
    }

    @Override
    public Object onMessage(String id, Object data) {
        if (HAS_BUILT_IN_SPLASH_SCREEN) {
            return null;
        }
        if ("splashscreen".equals(id)) {
            if ("hide".equals(data.toString())) {
                this.removeSplashScreen(false);
            } else {
                this.showSplashScreen(false);
            }
        }
        return null;
    }

    // Don't add @Override so that plugin still compiles on 3.x.x for a while
    public void onConfigurationChanged(Configuration newConfig) {
        if (newConfig.orientation != orientation) {
            orientation = newConfig.orientation;

            // Splash drawable may change with orientation, so reload it.
            if (splashDialog != null) {
                int layoutId = getSplashId();
                if (layoutId != 0) {
                    splashDialog.setContentView(layoutId);
                }
            }
        }
    }

    private void removeSplashScreen(final boolean forceHideImmediately) {
        if (HAS_BUILT_IN_SPLASH_SCREEN) {
            return;
        }
        cordova.getActivity().runOnUiThread(new Runnable() {
            public void run() {
                if (splashDialog != null && splashDialog.isShowing()) {//check for non-null splashImageView, see https://issues.apache.org/jira/browse/CB-12277
                    final int fadeSplashScreenDuration = getFadeDuration();
                    // CB-10692 If the plugin is being paused/destroyed, skip the fading and hide it immediately
                    if (fadeSplashScreenDuration > 0 && forceHideImmediately == false) {
                        final Handler handler = new Handler();
                        handler.postDelayed(new Runnable() {
                            public void run() {
                                splashDialog.dismiss();
                                splashDialog = null;
                            }
                        }, fadeSplashScreenDuration);
                    } else {
                        splashDialog.dismiss();
                        splashDialog = null;
                    }
                }
            }
        });
    }

    /**
     * Shows the splash screen over the full Activity
     */
    @SuppressWarnings("deprecation")
    private void showSplashScreen(final boolean hideAfterDelay) {
        if (HAS_BUILT_IN_SPLASH_SCREEN) {
            return;
        }
        final int splashscreenTime = preferences.getInteger("SplashScreenDelay", DEFAULT_SPLASHSCREEN_DURATION);
        final int layoutId = getSplashId();

        final int fadeSplashScreenDuration = getFadeDuration();
        final int effectiveSplashDuration = Math.max(0, splashscreenTime - fadeSplashScreenDuration);

        lastHideAfterDelay = hideAfterDelay;

        // Prevent to show the splash dialog if the activity is in the process of finishing
        if (cordova.getActivity().isFinishing()) {
            return;
        }
        // If the splash dialog is showing don't try to show it again
        if (splashDialog != null && splashDialog.isShowing()) {
            return;
        }
        if (layoutId == 0 || (splashscreenTime <= 0 && hideAfterDelay)) {
            return;
        }

        cordova.getActivity().runOnUiThread(new Runnable() {
            public void run() {
                // Get reference to display
                Context context = webView.getContext();

                // Create and show the dialog
                splashDialog = new Dialog(context, R.style.Theme_Custom_Splash);
                // check to see if the splash screen should be full screen
                if ((cordova.getActivity().getWindow().getAttributes().flags & WindowManager.LayoutParams.FLAG_FULLSCREEN)
                        == WindowManager.LayoutParams.FLAG_FULLSCREEN) {
                    splashDialog.getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,
                            WindowManager.LayoutParams.FLAG_FULLSCREEN);
                }

                splashDialog.setContentView(layoutId);
                splashDialog.setCancelable(false);
                splashDialog.show();

                updateAdImage();

                // Set Runnable to remove splash screen just in case
                if (hideAfterDelay) {
                    final Handler handler = new Handler();
                    handler.postDelayed(new Runnable() {
                        public void run() {
                            if (lastHideAfterDelay) {
                                removeSplashScreen(false);
                            }
                        }
                    }, effectiveSplashDuration);
                }
            }
        });
    }

    private void updateAdImage() {
        ImageView adImageView = splashDialog.findViewById(R.id.ad_image);
        if (adImageView != null) {
            adImageView.setImageResource(R.drawable.ad_test_image);
            // download file access code below
//            File documentsDirectory = cordova.getActivity().getFilesDir();
//            if (documentsDirectory != null) {
//                try {
//                    String imagePath = documentsDirectory.getAbsolutePath() + "/" + SplashScreen.FILE_NAME;
//                    File file = new File(imagePath);
//
//                    if (file.exists()) {
//                        Bitmap bitmap = BitmapFactory.decodeFile(imagePath);
//                        adImageView.setImageBitmap(bitmap);
//                    }
//                } catch (Exception e) {
//                }
//            }
        }
    }
}
