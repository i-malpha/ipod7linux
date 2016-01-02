// http://web.archive.org/web/20070111045309/http://ipodlinux.org/ITunesDB

public class ArtworkDB : Object {

	Gee.ArrayList<string> files;
	string filename;

	construct {
		files = new Gee.ArrayList<string>();
	}

	public ArtworkDB (string filename) {
		this.filename = filename;
	}

	public void add_thumb (string file) {
		files.add (file);
	}

	public int compute_size () {
		int header = 0x140;
		int mhsd = 0x4e0 - 0x140;
		int footer = 0x847 - 0x4e0 + 1;
		return header + mhsd*files.size + footer;
	}

	void write_int32(uint8[] buf, int offset, int64 data) {
		buf[offset] = (uint8) (data % 0x100);
		buf[offset+1] = (uint8) ((data % 0x10000)/0x100);
		buf[offset+2] = (uint8) ((data % 0x1000000)/0x10000);
		buf[offset+3] = (uint8) (data/0x1000000);
	}

	void write_header(uint8[] buf) {
		int offset = 0;
		write_int32 (buf, offset, 0x6466686d);
		
		offset += 4;
		// header size
		write_int32 (buf, offset, 0x84);
		

		offset += 4;
		// full size
		write_int32(buf, offset, compute_size ());

		// unknown
		offset += 4;
		offset += 4;
		
		write_int32(buf, offset, 0x06);

		offset += 4;
		
		write_int32(buf, offset, 0x03);

		offset += 4;
		offset += 4;
		write_int32(buf, offset, 0x65);
		offset += 17*4;
		
		offset = 0x3c;
		write_int32(buf, offset, 0xf9bac4ce);
		offset += 4;
		write_int32(buf, offset, 0x150417cf);


		// mhsd
		offset = 0x84;
		write_int32(buf, offset, 0x6473686d);
		offset += 4;
		write_int32(buf, offset, 0x60);
		// full mhsd size
		offset += 4;
		write_int32(buf, offset, 0x140-0x84 + files.size*(0x4e0-0x140));
	}

	void write_file(uint8[] buf, string file) {
		int offset = 0;
		write_int32(buf, 0, 0x6969686d);
		write_int32(buf, 4, 0x98);
	}

	void write_files (uint8[] buf) {
		int i = 0;
		int mhii = 0x4e0 - 0x140;
		foreach(var f in files) {
			unowned uint8[] b = buf[i:i+mhii];
			write_file(b, f);
			i += mhii;
		}
	}

	public void write_to_file () {
		uint8[] buf = new uint8[compute_size()];
		write_header(buf);

		unowned uint8[] buf_footer = buf[0x140 + files.size*(0x4e0-0x140):compute_size()];
		size_t ss;
		var f_end = File.new_for_path("ArtworkDB.end");
		f_end.read ().read_all(buf_footer, out ss, null);
		
		unowned uint8[] buf_mhii = buf[0x140:compute_size()];
		write_files(buf_mhii);
		
		var f = File.new_for_path(filename);
		f.replace_contents(buf, null, false, FileCreateFlags.NONE, null);

	}
}
