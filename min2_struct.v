struct Style {
	size  int
	color int
}

struct Theme {
	b3 Style
}

struct View {
	tag int
}

struct Cfg {
	style Style
}

struct TextView {
	tag int
}

fn theme() Theme {
	return Theme{}
}

fn text(c Cfg) View {
	return View{ tag: c.style.size }
}

fn main() {
	mut views := []View{}
	if views.len > 0 {
		views << text(Cfg{})
	} else {
		views << text(Cfg{
			style: Style{
				...theme().b3
				color: 9
			}
		})
	}
	println(views.len)
}
