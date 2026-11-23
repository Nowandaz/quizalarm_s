// The admin site moved to /soma/. This file only exists so that a browser
// still holding the old page (which loads "app.js" from here) is sent on
// to the new place instead of running an out-of-date copy.
location.replace('/soma/' + location.hash);
