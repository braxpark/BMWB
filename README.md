# BMWB
A web backend written in Zig. 


## Basic Usage
<p>
Place your index.html files in the pages directory. You can create sub-directories in pages that correspond to differnt route paths. For example for the URI "http://127.0.0.1:3000/foo/bar", the corresponding index.html should be found at "pages/foo/bar/index.html".
</p>
<br>
<p>Any stylesheets linked from any index.html should be kept in the styles directory.</p>
<br>
<p>Any scripts linked from any index.html should be kept in the scripts directory.</p>
<br>
To run, run the command `zig build run` and a server will run on the default port of 3000. 
<h3>
  TODO: <br>
  
</h3>
<p>
  Command arg for server port <br>
  JSX compatibility <br>
  Hot Reload <br>
  Vercel compatibility(?) <br>
</p>
