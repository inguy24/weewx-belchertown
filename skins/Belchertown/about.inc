#encoding UTF-8
<div class="entry-content about-outer" itemprop="text">
    <br>

<script type="text/javascript">showChart("about");</script>
<div class="entry-content about-outer" itemprop="text">

    <div class="row" style="margin-top:15px;">

        <div class="col-sm-4">
            <div id="webcam" class="tab-content"></div>
            <img src="/webcam/weather_cam.jpg" alt=""/>
			<img src="/images/weather_station.jpg" alt="" style="padding-top: 20px;"/>
            <table style="font-size:80%; margin:0 auto; text-align:center; /*margin-left:-50px;*/">
                <tbody>
                    <tr>
                        <td style="text-align:right; padding:4px 8px 0 0;">Hardware</td>
                        <td style="text-align:left; font-weight:bold; padding-top:4px;">Ambient Weather WS-5000-IP</td>
                    </tr>
                    <tr>
                        <td style="text-align:right; padding:4px 8px 0 0;">Camera</td>
                        <td style="text-align:left; font-weight:bold; padding-top:4px;">Amcrest Outdoor</a></td>
                    </tr>
		            <tr>
                        <td style="text-align:right; padding:4px 8px 0 0;">Location</td>
                        <td style="text-align:left; font-weight:bold; padding-top:4px;">Lat: 33.6568N Long: -117.9826W</a></td>
                    </tr>
		            <tr>
                        <td style="text-align:right; padding:4px 8px 0 0;">Altitude</td>
                        <td style="text-align:left; font-weight:bold; padding-top:4px;">40 feet</a></td>
                    </tr>
                </tbody>
            </table>
        </div>
        <div class="col-sm-8" style="padding-top:10px;">
          <p>This website is automatically updated in real time (about every 5 seconds) with weather observations from an Ambient Weather WS5000-IP personal weather station located in Huntington Beach, California on Atlanta Ave between Newland St and Beach Blvd. Weather data is pulled by the Weewx weather application from the station controller and served to you via an Apache webserver and EMQX websockets broker. The weather station provides the following readings:</p>

            <ul>
                <li>Temperature</li>
                <li>Humidity</li>
                <li>Dew Point</li>
                <li>Wind speed</li>
		<li>Wind direction</li>
                <li>Wind Gust</li>
                <li>Precipitation amount</li>
                <li>Precipitation rate</li>
                <li>UV radiation</li>
                <li>Solar radiation (irradiance)</li>
                <li>Barometric pressure</li>
                <li>Lightning count</li>
                <li>Lightning distance</li>
            </ul>

     <p>The rest of the observations on this website are created via
 software calculations derived from observed data. Quality control checks are run to make sure the data 
is valid. In addition, external data is collected to provide additional information on this site [see credits below].</p>
            
     <p>All weather observations are also posted to the following sites:</p>
            <ul>
                <li><a href="https://www.wunderground.com/dashboard/pws/KCAHUNTI278" target="_blank">KCAHUNTI278</a> on Weather Underground (app available)</li>
                <li><a href="https://ambientweather.net/dashboard/a6c0fd92d0e05308e750fa0dc7d4e5ba">GW2292</a> Ambient Weather (app available)</li>
				<li><a href="https://xweather.com">Vaisala XWeather</a></li>
                <li><a href="https://www.weather.gov/wrh/timeseries?site=G2292" target="_blank">GW2292</a> National Weather Service NOAA/CWOP Program</li>
            </ul>
     <div class="row">
        <div class="col-md-8"> <!-- Text paragraph -->
           <p>Sending weather data to the above sites helps with weather research and in creating more hyper-local predictions. As part of the <a href="http://wxqa.com/">NOAA/Citizen Weather Observer Program</a>, GW2292 is one of over 7,000 stations sending observation to NOAA, that are used by NWS and over 800 different organizations for research. </p>
        </div>
        <div class="col-md-4"> <!-- New graphic/image -->
           <img src="/images/noaa_logo.png" alt="NOAA/CWOP Logo" class="img-fluid" />
        </div>
     </div>
     <p>Credits:</p>
            <ul>
                <li>Forecast data from <a href="https://xweather.com/" target="_blank">Vaisala XWeather</a></li>
                <li>Earthquake data from <a href="http://earthquake.usgs.gov">USGS.gov Earthquake Catalog</a></li>
                <li>Radar courtesy of <a href="https://www.windy.com/?33.719,-118.003,5">Windy.com</a></li>
                <li>Surf forecast data from <a href="https://surf-forecast.com/"> Surf-Forecast.com</a></li>
                <li>Tide forecast data from <a href="https://tidespro.com/"> TidesPro</a></li>
            </ul>

      </div>
</div>
