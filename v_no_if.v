struct Style {
	size  int
	color int
}

struct Theme {
	b3 Style
}

interface View {
	tag int
}

@[minify]
struct TextCfg {
	text  string
	style Style
}

struct TextView implements View {
	TextCfg
	tag int
}

@[minify]
struct BoxCfg {
	id      int
	content []View
	action  fn (int) int = unsafe { nil }
}

struct BoxView implements View {
	BoxCfg
	tag int
}

fn theme() Theme {
	return Theme{ b3: Style{ size: 10, color: 1 } }
}

fn text(c TextCfg) View {
	return TextView{ TextCfg: c, tag: c.style.size }
}

fn box(c BoxCfg) View {
	return BoxView{ BoxCfg: c, tag: c.content.len + c.id }
}

fn main() {
	busy := false
	mut views := []View{}
	_ = busy
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
	println(views.len)
}
