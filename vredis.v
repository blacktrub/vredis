module vredis

import net
import strconv

pub struct ConnOpts {
	port int=6379
	host string='127.0.0.1'
}

pub struct Redis {
	socket net.Socket
}

pub struct SetOpts {
	ex       int=-4
	px       int=-4
	nx       bool=false
	xx       bool=false
	keep_ttl bool=false
}

// https://github.com/v-community/learn_v_in_y_minutes/blob/master/learnv.v
// https://github.com/vlang/v/blob/master/vlib/net/socket_test.v
// https://redis.io/topics/protocol
pub fn connect(opts ConnOpts) ?Redis {
	socket := net.dial(opts.host, opts.port) or {
		return error(err)
	}
	return Redis{
		socket: socket
	}
}

pub fn (r Redis) disconnect() {
	r.socket.close() or { }
}

pub fn (r Redis) set(key, value string) bool {
	message := 'SET "$key" "$value"\r\n'
	r.socket.write(message) or {
		return false
	}
	res := r.socket.read_line()[0..3]
	match res {
		'+OK' {
			return true
		}
		else {
			return false
		}
	}
}

pub fn (r Redis) set_opts(key, value string, opts SetOpts) bool {
	ex := if opts.ex == -4 && opts.px == -4 { '' } else if opts.ex != -4 { ' EX $opts.ex' } else { ' PX $opts.px' }
	nx := if opts.nx == false && opts.xx == false { '' } else if opts.nx == true { ' NX' } else { ' XX' }
	keep_ttl := if opts.keep_ttl == false { '' } else { ' KEEPTTL' }
	message := 'SET "$key" "$value"$ex$nx$keep_ttl\r\n'
	r.socket.write(message) or {
		return false
	}
	res := r.socket.read_line()[0..3]
	match res {
		'+OK' {
			return true
		}
		else {
			return false
		}
	}
}

pub fn (r Redis) setex(key string, seconds int, value string) bool {
	return r.set_opts(key, value, SetOpts{
		ex: seconds
	})
}

pub fn (r Redis) psetex(key string, millis int, value string) bool {
	return r.set_opts(key, value, SetOpts{
		px: millis
	})
}

pub fn (r Redis) setnx(key string, value string) int {
	res := r.set_opts(key, value, SetOpts{
		nx: true
	})
	return if res == true { 1 } else { 0 }
}

pub fn (r Redis) expire(key string, seconds int) ?int {
	message := 'EXPIRE "$key" $seconds\r\n'
	r.socket.write(message) or {
		return error(err)
	}
	res := r.socket.read_line()
	count := parse_int(res)
	return count
}

pub fn (r Redis) pexpire(key string, millis int) ?int {
	message := 'PEXPIRE "$key" $millis\r\n'
	r.socket.write(message) or {
		return error(err)
	}
	res := r.socket.read_line()
	count := parse_int(res)
	return count
}

pub fn (r Redis) expireat(key string, timestamp int) ?int {
	message := 'EXPIREAT "$key" $timestamp\r\n'
	r.socket.write(message) or {
		return error(err)
	}
	res := r.socket.read_line()
	count := parse_int(res)
	return count
}

pub fn (r Redis) pexpireat(key string, millistimestamp i64) ?int {
	message := 'PEXPIREAT "$key" $millistimestamp\r\n'
	r.socket.write(message) or {
		return error(err)
	}
	res := r.socket.read_line()
	count := parse_int(res)
	return count
}

pub fn (r Redis) get(key string) ?string {
	message := 'GET "$key"\r\n'
	r.socket.write(message) or {
		return error(err)
	}
	res := r.socket.read_line()
	len := parse_int(res)
	if len == -1 {
		return error('key not found')
	}
	return r.socket.read_line()[0..len]
}

pub fn (r Redis) ttl(key string) ?int {
	message := 'TTL "$key"\r\n'
	r.socket.write(message) or {
		return error(err)
	}
	res := r.socket.read_line()
	count := parse_int(res)
	return count
}

pub fn (r Redis) pttl(key string) ?int {
	message := 'PTTL "$key"\r\n'
	r.socket.write(message) or {
		return error(err)
	}
	res := r.socket.read_line()
	count := parse_int(res)
	return count
}

pub fn (r Redis) del(key string) ?int {
	message := 'DEL "$key"\r\n'
	r.socket.write(message) or {
		return error(err)
	}
	res := r.socket.read_line()
	count := parse_int(res)
	return count
}

pub fn (r Redis) flushall() bool {
	message := 'FLUSHALL\r\n'
	r.socket.write(message) or {
		return false
	}
	res := r.socket.read_line()[0..3]
	match res {
		'+OK' {
			return true
		}
		else {
			return false
		}
	}
}

fn parse_int(res string) int {
	mut i := 0
	for ; i < res.len; i++ {
		if res[i] == `\r` {
			break
		}
	}
	slen := res[1..i]
	return strconv.atoi(slen)
}
