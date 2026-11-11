// CloudFront viewer-request function: clean URLs for the portfolio.
//   /projects/batak-type/  -> serves projects/batak-type/index.html
//   /projects/batak-type   -> 301 to /projects/batak-type/
//   old .html addresses    -> 301 to their new homes, so shared links keep working
var MOVED = {
  '/index.html': '/',
  '/extras.html': '/extras/',
  '/portfolio.html': '/',
  '/portfolio/': '/',
  '/Projects/Cloudcv.html': '/projects/cloud-resume/',
  '/Projects/LocallyRanLLM.html': '/projects/local-llm/',
  '/Projects/CloudBasedGallery.html': '/projects/cloud-gallery/',
  '/Projects/AssettoCorsaTelemetry.html': '/projects/ai-race-engineer/',
  '/Projects/LightweightCustomSpotifyInterface.html': '/projects/smart-display/',
  '/Projects/TelemetryController.html': '/projects/race-simulator/',
  '/Projects/BatakType.html': '/projects/batak-type/',
  '/Projects/eventbooking.html': '/projects/batak-type/'
};

function redirect(location) {
  return {
    statusCode: 301,
    statusDescription: 'Moved Permanently',
    headers: { location: { value: location } }
  };
}

function handler(event) {
  var request = event.request;
  var uri = request.uri;

  if (MOVED[uri]) {
    return redirect(MOVED[uri]);
  }
  if (uri.charAt(uri.length - 1) === '/') {
    request.uri = uri + 'index.html';
  } else if (uri.lastIndexOf('.') < uri.lastIndexOf('/')) {
    // a folder without its trailing slash, e.g. /extras
    return redirect(uri + '/');
  }
  return request;
}
