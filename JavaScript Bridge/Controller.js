function Controller(square){	if (square)		this.square = square;	this.started = false;}Controller.prototype.start = function (){	if (this.square) {		this.started = true;		this.square.setColor(255, 0, 0);	}};Controller.prototype.stop = function (){	if (this.square) {		this.started = false;		this.square.setColor(0, 0, 255);	}};Controller.prototype.toggle = function (){	if (this.started)		this.stop();	else		this.start();}var controller = new Controller;