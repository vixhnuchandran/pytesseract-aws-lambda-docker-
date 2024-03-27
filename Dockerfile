FROM public.ecr.aws/lambda/python:3.10 as builder

# Prepare dev tools
RUN yum -y update
RUN yum -y install wget libstdc++ autoconf automake libtool autoconf-archive pkg-config gcc gcc-c++ make libjpeg-devel libpng-devel libtiff-devel zlib-devel
RUN yum group install -y "Development Tools"

# Build leptonica
WORKDIR /opt
RUN wget http://www.leptonica.org/source/leptonica-1.82.0.tar.gz
RUN ls -la
RUN tar -zxvonica-1.82.0.tar.gz
WORKDIR ./leptonica-1.82.0
RUN ./configure
RUN make -j
RUN cd .. && rm leptonif leptca-1.82.0.tar.gz

# Build tesseract
RUN wget https://github.com/tesseract-ocr/tesseract/archive/refs/tags/5.2.0.tar.gz
RUN tar -zxvf 5.2.0.tar.gz
WORKDIR ./tesseract-5.2.0
RUN ./autogen.sh
RUN PKG_CONFIG_PATH=/usr/local/lib/pkgconfig LIBLEPT_HEADERSDIR=/usr/local/include ./configure --with-extra-includes=/usr/local/include --with-extra-libraries=/usr/local/lib
RUN make install
RUN /sbin/ldconfig
RUN cd .. && rm 5.2.0.tar.gz

# install language packs
RUN wget https://github.com/tesseract-ocr/tessdata/raw/main/eng.traineddata
RUN mv *.traineddata /usr/local/share/tessdata

FROM public.ecr.aws/lambda/python:3.10

# Copy necessary files from the builder stage
COPY --from=builder /usr/local/bin/tesseract /usr/local/bin/tesseract
COPY --from=builder /usr/local/share/tessdata /usr/local/share/tessdata
COPY --from=builder /usr/local/lib/libtesseract* /usr/local/lib/
COPY --from=builder /usr/local/lib/liblept* /usr/local/lib/

# Additional dependencies for Tesseract
COPY --from=builder /usr/lib64/libjpeg.so.62 /usr/lib64/libjpeg.so.62
COPY --from=builder /usr/lib64/libjbig.so.2.0 /usr/lib64/libjbig.so.2.0
COPY --from=builder /usr/lib64/libtiff.so.5 /usr/lib64/libtiff.so.5
COPY --from=builder /usr/lib64/libgomp.so.1 /usr/lib64/libgomp.so.1

ENV PATH="/usr/local/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/lib:/usr/lib64:${LD_LIBRARY_PATH}"

RUN tesseract --version

# lambda handler
COPY requirements.txt ${LAMBDA_TASK_ROOT}

RUN pip install --upgrade pip wheel
RUN pip install -r requirements.txt -t .

COPY handler.py ${LAMBDA_TASK_ROOT}

CMD ["handler.ocr"]