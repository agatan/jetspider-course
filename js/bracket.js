var x = [1, 2, 3];
p(x[1]);

function Class(x) {
    this.index = x;
}

var y = new Class(2);
p(y['index']);
