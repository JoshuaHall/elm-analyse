module.exports = function(targetFiles) {
    const Elm = require('./elm');
    const fs = require('fs');
    var app = Elm.Main.worker();

    var counter = 0;
    var failed = 0;
    var failedFiles = [];
    var invalid = 0;
    var totalTime = 0;

    app.ports.parseResponse.subscribe(function(result) {
        counter++;
        console.log(
            counter + ' Analysed file:',
            result[0],
            'in milliseconds ' + result[2]
        );
        totalTime += result[2];

        if (result[1] === 'Nothing') {
            console.log('  > Failed');
            failedFiles.push(result[0]);
            failed++;
        }

        analyseNextFile();
    });

    function analyseNextFile() {
        const next = targetFiles.shift();
        if (!next) {
            console.log('Failed:', failed);
            console.log('Invalid:', invalid);
            console.log('Counter:', counter);
            console.log('Total Time:', totalTime / 1000);
            console.log();
            console.log(JSON.stringify(failedFiles, null, '  '));
            return;
        }

        const content = fs
            .readFileSync(next[0], {
                encoding: 'utf-8'
            })
            .toString();

        var lines = content.split('\n');
        var firstLine = lines[0];
        var startsWithModule = firstLine.startsWith('module');
        var firstLineContainsWhere = firstLine.indexOf('where') != -1;

        var matched =
            content.match(/\nport [a-z][a-zA-Z0-9_]*'? =/) ||
            // content.match(/`([A-Z][a-zA-Z0-9_]*\.)*[a-z][a-zA-Z0-9_]*`/) ||
            (startsWithModule && firstLineContainsWhere);

        if (matched) {
            invalid++;
            analyseNextFile();
            return;
        }

        app.ports.onFile.send([next[0], content]);
    }

    analyseNextFile();
};
