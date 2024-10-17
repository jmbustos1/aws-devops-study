var port = process.env.PORT || 3000,
    http = require('http'),
    fs = require('fs'),
    indexHtml = fs.readFileSync('index.html'),
    snakeHtml = fs.readFileSync('index2.html');

var log = function(entry) {
    fs.appendFileSync('/tmp/sample-app.log', new Date().toISOString() + ' - ' + entry + '\n');
};

var server = http.createServer(function (req, res) {
    if (req.method === 'POST') {
        var body = '';
        req.on('data', function(chunk) {
            body += chunk;
        });

        req.on('end', function() {
            if (req.url === '/') {
                log('Received message: ' + body);
            } else if (req.url === '/scheduled') {
                log('Received task ' + req.headers['x-aws-sqsd-taskname'] + ' scheduled at ' + req.headers['x-aws-sqsd-scheduled-at']);
            }

            res.writeHead(200, 'OK', {'Content-Type': 'text/plain'});
            res.end();
        });
    } else {
        if (req.url === '/snake') {
            res.writeHead(200, {'Content-Type': 'text/html'});
            res.write(snakeHtml);
        } else {
            res.writeHead(200, {'Content-Type': 'text/html'});
            res.write(indexHtml);
        }
        res.end();
    }
});

server.listen(port);
console.log('Server running at http://127.0.0.1:' + port + '/');