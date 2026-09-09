struct Style {
	size  int
	color int
}

struct Theme {
	b3 Style
	n4 Style
}

struct View {
	tag int
}

struct TextCfg {
	text  string
	style Style
}

struct BoxCfg {
	id      int
	content []View
	action  fn (int) int = unsafe { nil }
}

fn theme() Theme {
	return Theme{ b3: Style{ size: 10, color: 1 } }
}

fn text(c TextCfg) View {
	return View{ tag: c.style.size }
}

fn box(c BoxCfg) View {
	return View{ tag: c.content.len + c.id }
}

fn main() {
	busy := false
	mut views := []View{}
	if busy {
		views << box(id: 1, content: [text(text: 'Cancel')])
	} else {
		views << box(
			id:      2
			content: [
				text(
					text:  'Scan'
					style: Style{
						...theme().b3
						color: 9
					}
				),
			]
			action:  fn (x int) int {
				return x
			}
		)
	}
	println(views)
}
