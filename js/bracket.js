var x = [1, 2, 3];
p(x[1]);

function Class(x) {
    this.index = x;
}

var y = new Class(2);
var accessor = 'index';
p(y[accessor]);
p(y[accessor]++);
p(y[accessor]);

y[accessor] = one;
p(y[accessor]);
p(y.index);

function show_index() {
    p(this.index);
}
y['m'] = show_index;
var m = 'm';
y[m]();
