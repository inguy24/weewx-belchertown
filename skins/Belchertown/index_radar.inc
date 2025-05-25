<!-- Rename this file to index_radar.inc 
See other example at https://github.com/poblabs/weewx-belchertown/issues/703 -->
<div id="tabs-container">
    <!-- Nav tabs -->
    <ul class="nav nav-tabs tabs-menu" role="tablist">
        <li role="presentation"><a href="#radar" aria-controls="radar" role="tab" data-toggle="tab">Radar</a></li>
        <li role="presentation" class="active"><a href="#webcam" aria-controls="webcam" role="tab" data-toggle="tab">Webcam</a></li>
        <li role="presentation"><a href="#timelapse" aria-controls="timelapse" role="tab" data-toggle="tab">Webcam Timelapse</a></li>
    </ul>

    <!-- Tabs contents -->
    <div class="tab">
        <!-- Radar Tab -->
        <div id="radar" class="tab-content" style="display:none;">
            <div class="radar_image">$radar_html</div>
        </div>

        <!-- Webcam Tab -->
        <div id="webcam" class="tab-content" style="display:block;">
            <a name="webcam" href="webcam/weather_cam.jpg" target="_blank">
                <img src="webcam/weather_cam.jpg" alt="Live Webcam">
            </a>
        </div>

        <!-- Webcam Timelapse Tab -->
        <div id="timelapse" class="tab-content" style="display:none;">
            <div class="timelapse-video-container">
                <video class="timelapse-video" controls playsinline loop>
                    <source src="/webcam/weewx_timelapse.mp4" type="video/mp4">
                    Your browser does not support the video tag.
                </video>
            </div>
        </div>
    </div>
</div>

<!-- JavaScript to handle tab switching, webcam refresh, and timelapse reload -->
<script type="text/javascript">
jQuery(document).ready(function() {
    reloadWebcam();
    reloadTimelapse();

    // Refresh webcam image every 1 minutes
    setInterval(reloadWebcam, 60000);

    // Refresh timelapse video every 15 minutes
    setInterval(reloadTimelapse, 900000);

    // Handle tab switching
    jQuery('.tabs-menu a').click(function(event) {
        event.preventDefault();
        jQuery(this).parent().addClass("active");
        jQuery(this).parent().siblings().removeClass("active");

        var activeTab = jQuery(this).attr("href");
        jQuery('.tab-content').not(activeTab).hide();
        jQuery(activeTab).fadeIn();
    });
});

// Reload webcam image (with cache busting)
function reloadWebcam() {
    jQuery('#webcam img').each(function() {
        var newSrc = jQuery(this).attr('src').split('?')[0] + '?' + Math.floor(Math.random() * 999999999);
        jQuery(this).attr('src', newSrc);
    });
}

// Reload timelapse video (with cache busting)
function reloadTimelapse() {
    jQuery('#timelapse video source').each(function() {
        var newSrc = jQuery(this).attr('src').split('?')[0] + '?' + Math.floor(Math.random() * 999999999);
        jQuery(this).attr('src', newSrc);
        jQuery(this).parent()[0].load(); // Reload the video element
    });
}
</script>

<!-- Optional styling for the tab menu -->
<style>
.dark .tabs-menu > li > a {
    padding: 0px 5px;
}

.dark .nav-tabs>li.active>a,
.dark .nav-tabs>li.active>a:focus,
.dark .nav-tabs>li.active>a:hover {
    color: #e5554e;
}

.tabs-menu > li > a {
    padding: 0px 5px;
}

.toprow-height {
    min-height: 402px !important;
}
</style>
